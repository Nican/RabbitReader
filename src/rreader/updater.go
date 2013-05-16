package rreader

import (
	"fmt"
	"strings"
	"sync"
	"github.com/jteeuwen/go-pkg-xmlx"
	"net/http"
	"errors"
	"time"
	"regexp"
)

var gUpdateMutex sync.Mutex;

func UpdateFeeds(age int64) error {
	gUpdateMutex.Lock()
	defer gUpdateMutex.Unlock()
	
	rows, _, err := GetConnection().Query("SELECT `id`,`feedURL` FROM `feed` WHERE `last_update` < %d AND `disabled`=0",
		time.Now().Unix() - age * 60 )
	
	if err != nil {
		return err
	}
	
	waitGroup := new (sync.WaitGroup)
	
	update := func( feedId int, uri string ){		
		err := updateFeed( feedId, uri )
		
		fmt.Printf("Reading feed (%d): %s\n", feedId, uri )
		if err != nil {
			fmt.Println(err.Error())
		}
		
		waitGroup.Done()
	
	}
	
	//We can "go" this loop, but the mysql module does not like having concurrent transactions
	for _, feed := range rows {
		waitGroup.Add(1)
		go update( feed.Int(0), feed.Str(1) )
	}
	
	waitGroup.Wait()
	
	_, _, err = GetConnection().QueryFirst("CALL update_unread()")

	if err != nil {
		return err
	}
	
	fmt.Println("Updated finished!")
	
	return nil
}

func getContent(node *xmlx.Node) string {
	const ns = "*"
	content := ""
	
	checkContent := func( nodeName string ){
		nodeContent := node.S(ns, nodeName)
		
		if len( nodeContent ) > len(content) {
			content = nodeContent
		}
	}
	
	//This is for WordPress Feeds, which put all the ir content in <content:encoded> 
	//See Steam (http://store.steampowered.com/feeds/news.xml) and Wordpress (http://blog.nican.net/feed/)
	checkContent("encoded")
	
	//For atom feeds, look at content
	checkContent("content")
	
	//Check for the actual RSS standard spot to put content
	checkContent("description")
	checkContent("comments")
	
	return content
}

func getLink(node *xmlx.Node) string {
	link := node.SelectNode("*", "link")
	href := link.As("", "href")
	
	if href == "" {
		href = node.S("*", "link")
	}
	return href	
}

func getGUID(node *xmlx.Node) string {
	guid := node.S("*", "guid")
	
	if guid == "" {
		guid = node.S("*", "id")
	}
	return guid	
}

func getAuthor(node *xmlx.Node) string {
	if tn := node.SelectNode("*", "author"); tn != nil {
		author := tn.S("*", "name")
		
		if author != "" {
			return author
		}
		
		return tn.Value	
	}
	
	return ""	
}

//It is only a matter of time before this function fails
//But I do not see any simpler solutions with Go
//SOBODY FIND ME A BETTER WAY!
func parseTime(input string) (time.Time, error) {
	if input == "" {
		return time.Now(), nil
	}
	
	formats := [...]string{"2006-01-02T15:04:05Z",
		"2006-01-02 15:04:05-07",
		"2006-01-02T15:04:05-07:00",
		"Mon Jan 2 15:04:05 -0700 MST 2006",
		"Mon, 02 Jan 2006 15:04:05 -07:00",
		"Mon, 02 Jan 2006 15:04:05 -0700",	
		"Mon, 02 January 2006 15:04:05 -0700",
		"Mon, 2 Jan 2006 15:04:05 -0700",
		"Mon, 2 Jan 2006 15:04:05 MST",
		"Mon, 2 January 2006 15:04:05 -0700",
		"Monday 2 Jan 2006 15:04:05 MST",
		"Monday, 2 Jan 2006 15:04:05 MST",
		"Mon, 02 Jan 2006 15:04:05 MST" }

	for _, format := range(formats){
		t, err := time.Parse(format, input)
		if err == nil {
			return t, nil
		}
	}
	
	//Last drastic request
	//Blame: http://pipes.yahoo.com/pipes/pipe.run?_id=22a693bd3326845a59474b926185ff0e&_render=rss
	r, err := regexp.Compile(`(\w+),?\s*(\d+)\s*(\w+)\s*(\d{4})\s*(\d+):(\d+):(\d+)(.*)`)

    if err != nil {
        panic(err)
    }
    
    result := r.FindStringSubmatch(input)
    
    input2 := fmt.Sprintf("%s, %s %s %s %s:%s:%s %s",
    	result[1][0:3],
    	result[2],
    	result[3][0:3],
    	result[4],
    	result[5],
    	result[6],
    	result[7],
    	result[8] )
    	
    for _, format := range(formats){
		t, err := time.Parse(format, input2)
		if err == nil {
			return t, nil
		}
	}
    
	
	return time.Now(), errors.New(fmt.Sprintf("Could not parse %s", input))
}

type onItem func(node *xmlx.Node)

func findItems(node *xmlx.Node, callback onItem){
	if node.Name.Local == "item" || node.Name.Local == "entry" {
		callback( node )
	}

	for _ , child := range node.Children {
		findItems(child, callback)
	}
} 

func updateFeed( feedId int, uri string ) (retErr error ) {
	
	const ns = "*"
	conn := gConn.Clone()
	if err := conn.Connect(); err != nil {
		return err
	}
	
	transaction, err := conn.Begin()
	if err != nil {
		return err
	}
	
	defer func() {
        if e := recover(); e != nil {
            transaction.Rollback()
            retErr = e.(error)
        } else {
        	transaction.Commit()
        }
        conn.Close()
    }()
    
    _, _, err = transaction.Query("UPDATE `feed` SET `last_update`=%d WHERE `id`=%d", time.Now().Unix(), feedId)
	
	if err != nil {
		panic(err)
	}
    
    doc := xmlx.New()

	if err = doc.LoadUriClient(uri, http.DefaultClient, CharsetReader); err != nil {
		return err
	}
	
	findFeedEntry := func( title string, content string, date string, guid string ) bool {
		search := ""
		
		if len(guid) > 0 {
			search = fmt.Sprintf("`guid`='%s'", gConn.Escape(guid))	
		} else {
			where := make([]string, 0)
			
			if len(date) > 0 {
				where = append(where, fmt.Sprintf("`published`='%s'", gConn.Escape(date)))
			}
			
			if len(content) > 0 {
				where = append(where, fmt.Sprintf("`content`='%s'", gConn.Escape(content)))
			}
			
			if len(title) > 0 {
				where = append(where, fmt.Sprintf("`title`='%s'", gConn.Escape(title)))
			}
			
			if len(where) == 0 {
				panic( fmt.Sprintf("Can not search item! %s", title ) )
			}
			search = strings.Join( where, " OR ")
		}
	
		rows, _, err := transaction.Query("SELECT `id` FROM `feed_entry` WHERE `feed_id`=%d AND (%s)", 
			feedId,
			search )
			
		if err != nil {
			panic(err)
		}
			
		if len(rows) > 1 {
			ids := make([]string, len(rows))
			
			for i, row := range rows {
				ids[i] = row.Str(0) 
			}
		
			err := fmt.Sprintf("Found more than one answer! (%s)", strings.Join(ids, ","))
			panic(errors.New(err))
		}
		
		return len(rows) == 1	
	}
	
	findItems( doc.Root, func(node *xmlx.Node){
		content := getContent(node) 
		link := getLink(node)
		author := getAuthor(node)
		guid := getGUID(node)
		title := node.S(ns, "title")
		published := node.S(ns, "pubDate")
		if len( published ) == 0 {
			published = node.S(ns, "published")
		}
		
		parsedTime, err := parseTime(published)
		
		if err != nil {
			fmt.Printf("Warning: Failed to parse (%s)\n", published ) 
		}
		
		if parsedTime.After( time.Now() ){
			parsedTime = time.Now()
		}
		
		//Thanks VGCats! You have no content! http://www.vgcats.com/vgcats.rdf.xml
		//if content == "" {
		//	panic(errors.New("Could not find content"))
		//}
	
		if findFeedEntry(title, content, published, guid ) {
			return
		}
		
		_, _, err = transaction.Query("INSERT INTO `feed_entry`(`feed_id`,`title`,`content`,`published`,`updated`,`author`,`link`,`guid`) VALUES (%d,'%s','%s','%s',%d,'%s','%s','%s')", 
			feedId,
			gConn.Escape(title),
			gConn.Escape(content),
			gConn.Escape(published),
			parsedTime.Unix(),
			gConn.Escape(author),
			gConn.Escape(link),
			gConn.Escape(guid))
			
		if err != nil {
			panic(err)
		}
		
		_, _, err = transaction.Query("UPDATE `user_feed` SET `unread_items`=`unread_items`+1 WHERE `feed_id`=%d", feedId)
		
		if err != nil {
			panic(err)
		}
	
	} )
	
	return nil
}



