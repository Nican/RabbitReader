package rreader

import (
	"github.com/jteeuwen/go-pkg-rss"
	"fmt"
	"strings"
	"sync"
)

/*
var gFeedUpdater *feeder.Feed;


func InitializeUpdater() {
	gFeedUpdater = feeder.New(5, true, chanHandler, itemHandler)
	var err error
	uri := "https://news.ycombinator.com/rss"
	
	fmt.Println("FIRST TIME")
	if err = gFeedUpdater.Fetch(uri, nil); err != nil {
		fmt.Println("%s >>> %s", uri, err)
		return
	}
	
	//uri = "http://cyber.law.harvard.edu/rss/examples/rss2sample.xml"
	
	fmt.Println("SECOND TIME")
	if err = gFeedUpdater.Fetch(uri, nil); err != nil {
		fmt.Println("%s >>> %s", uri, err)
		return
	}
}
*/
func UpdateFeeds() error {
	
	rows, _, err := GetConnection().Query("SELECT `id`,`feedURL` FROM `feed` WHERE `last_update` < DATE_SUB(now(), INTERVAL 6 HOUR) AND `disabled`=0")
	
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
	
	for _, feed := range rows {
		waitGroup.Add(1)
		update( feed.Int(0), feed.Str(1) )
	}
	
	waitGroup.Wait()
	
	//updateFeed(22, "http://news.ycombinator.com/rss" )
	
	return nil
}

func updateFeed( feedId int, uri string ) (retErr error ) {

	transaction, err := gConn.Begin()
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
    }()
	
	findFeedEntry := func( item *feeder.Item ) bool {
		where := make([]string, 0)
		
		if len(item.PubDate) > 0 {
			published := fmt.Sprintf("`published`='%s'", gConn.Escape(item.PubDate))
			where = append(where, published)
		}
		
		if len(item.Description) > 0 {
			content := fmt.Sprintf("`content`='%s'", gConn.Escape(item.Description))
			where = append(where, content)
		}
		
		if len(item.Title) > 0 {
			title := fmt.Sprintf("`title`='%s'", gConn.Escape(item.Title))
			where = append(where, title)
		}
		
		if len(where) == 0 {
			panic( fmt.Sprintf("Can not search item! %s", item ) )
		}
	
		rows, _, err := transaction.Query("SELECT `id` FROM `feed_entry` WHERE `feed_id`=%d AND (%s)", 
			feedId,
			strings.Join( where, " OR ") )
			
		if err != nil {
			panic(err)
		}
			
		if len(rows) > 1 {
			panic("Found more than one answer!")
		}
		
		return len(rows) == 1	
	}
	
	chanHandler := func (feed *feeder.Feed, newchannels []*feeder.Channel) {
		//fmt.Println(len(newchannels), "new channel(s) in", feed.Url)
	}
	
	itemHandler := func(feed *feeder.Feed, ch *feeder.Channel, newitems []*feeder.Item) {
		for _, item := range newitems {
			//item.Title item.Links[0] item.Description item.Description item.Author item.Comments 			
			if findFeedEntry(item) {
				continue
			}
			
			_, _, err := transaction.Query("INSERT INTO `feed_entry`(`feed_id`,`title`,`content`,`comments`,`published`,`updated`,`author`,`link`,`guid`) VALUES (%d,'%s','%s','%s',now(),'%s','%s','%s','%s')", 
				feedId,
				gConn.Escape(item.Title),
				gConn.Escape(item.Description),
				gConn.Escape(item.Comments),
				gConn.Escape(item.PubDate),
				gConn.Escape(item.Author.Name),
				gConn.Escape(item.Links[0].Href),
				gConn.Escape(item.Guid))
				
			if err != nil {
				panic(err)
			}
			
			_, _, err = transaction.Query("UPDATE `user_feed` SET `unread_items`=`unread_items`+1 WHERE `feed_id`=%d", feedId)
			
			if err != nil {
				panic(err)
			}
		}
	}
	
	feedUpdater := feeder.New(5, true, chanHandler, itemHandler)
	
	if err = feedUpdater.Fetch(uri, nil); err != nil {
		panic(err)
	}
	
	_, _, err = transaction.Query("UPDATE `feed` SET `last_update`=now() WHERE `id`=%d", feedId)
	
	if err != nil {
		panic(err)
	}
	
	return nil
}



