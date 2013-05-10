package rreader

import (
	_ "database/sql"
	"github.com/ziutek/mymysql/thrsafe"
	"github.com/ziutek/mymysql/mysql"
	_ "github.com/ziutek/mymysql/native" // Native engine
	"strings"
	"time"
	//"fmt"
)

type SQLImporter struct {
	userId  uint32
	transaction mysql.Transaction
	feedIds map[string]uint32
	groupIds map[string]uint32
	entryIds []string
}

var gConn mysql.Conn

func GetConnection() mysql.Conn {
	return gConn
}

func OpenDB() {
	gConn = thrsafe.New("tcp", "", "192.168.1.6:3306", "root", "password", "nican")
	
	err := gConn.Connect()
	if err != nil {
		panic(err)
	}
}
/*
func (self SQLImporter) getGroup(group string) uint32 {
	groupId, present := self.groupIds[group]
	
	if present {
		return groupId
	}

	rows, _, err := self.transaction.Query("SELECT `group_id` FROM `feedgroup` WHERE `title`='%s' AND user_id=%d", group, self.userId)
		
	if err != nil {
		panic(err)
	}
	
	if len(rows) == 0 {
		_, res, err := self.transaction.Query("INSERT INTO `feedgroup`(`user_id`,`title`) VALUES (%d,'%s')",
			self.userId,
			group)
			
		if err != nil {
			panic(err)
		}
		
		groupId = uint32(res.InsertId())
	} else {
		groupId = uint32(rows[0].Int(0))
	}
	
	self.groupIds[group] = groupId
	
	return groupId
}
*/
func (self SQLImporter) OnSubscription(feed *Subscription, group string) {

	rows, res, err := self.transaction.Query("SELECT `id` FROM `feed` WHERE `feedURL`='%s'", feed.XmlUrl)

	if err != nil {
		panic(err)
	}

	if len(rows) > 0 {
		self.feedIds[feed.XmlUrl] = uint32(rows[0].Uint(0))
		return
	}

	_, res, err = self.transaction.Query("INSERT IGNORE INTO `feed`(`title`,`description`,`link`,`last_update`,`feedURL`) VALUES ('%s','%s','%s','%s','%s')",
		gConn.Escape(feed.Title),
		gConn.Escape(feed.Text),
		feed.HtmlUrl,
		"0",
		feed.XmlUrl)

	if err != nil {
		panic(err)
	}
	
	feedId := uint32(res.InsertId())
	self.feedIds[feed.XmlUrl] = feedId
	
	_, res, err = self.transaction.Query("INSERT IGNORE INTO `user_feed`(`user_id`,`feed_id`,`newest_read`,`unread_items`,`group`) VALUES (%d, %d, '%s', %d,'%s')",
		self.userId, 
		feedId, 
		time.Now(), 
		0,
		gConn.Escape(group) )
		
	if err != nil {
		panic(err)
	}	
	
	/*
	if group != "" {
		groupId := self.getGroup(group)
		
		_, _, err = self.transaction.Query("INSERT INTO `feedgroup_item`(`feedgroup_id`,`feed_id`) VALUES (%d,%d)",
				groupId,
				feedId )
	
		if err != nil {
			panic(err)
		}
		
	}
	*/
	
}

func (self SQLImporter) ReadFeedItem(item FeedItem) {
	if !strings.HasPrefix(item.Origin.StreamId, "feed/") {
		//Ignoring unkown items for now, such as 'pop/topic/top/language/en' found in my feed (youtube video)
		//TODO: Fill the edge cases of unkown stream id.		
		//panic( errors.New("Unkown type of feed '" + item.Origin.StreamId + "'!") )
	}
	
	//Check if we already added the item.
	for _, id := range self.entryIds {
		if id == item.Id {
			return
		}
	}
	
	feedUrl := item.Origin.StreamId[5:]

	//Look for the feed id
	feedId, present := self.feedIds[feedUrl]

	//Found a item that was starred, but then removed
	//We will add the feed as disabled
	if !present {
		rows, _, err := self.transaction.Query("SELECT `id` FROM `feed` WHERE `feedURL`='%s'", feedUrl)

		if err != nil {
			panic(err)
		}
		
		
		if len(rows) > 0 {
			feedId = uint32(rows[0].Uint(0))
		} else {
	
			_, res, err := self.transaction.Query("INSERT INTO `feed`(`title`,`description`,`link`,`last_update`,`feedURL`,`disabled`) VALUES ('%s','%s','%s','%s','%s',1)",
				"",
				"",
				feedUrl,
				"0",
				feedUrl)
	
			if err != nil {
				panic(err)
			}
	
			feedId = uint32(res.InsertId())
		}
		
		//Update the feedId for future objects
		self.feedIds[feedUrl] = feedId
	}
	
	content := item.Summary.Content
	
	if len(item.Content.Content) > len(content) {
		content = item.Content.Content
	}
	
	_, _, err := self.transaction.Query("INSERT IGNORE INTO `feed_entry`(`feed_id`,`title`,`content`,`link`,`published`,`updated`,`author`,`guid`) VALUES (%d,'%s','%s','%s','%s','%s','%s','%s')",
		feedId,
		gConn.Escape(item.Title),
		gConn.Escape(content),
		gConn.Escape( item.Alternate[0].Href ),
		time.Unix( int64(item.Published), 0 ),
		time.Unix( int64(item.Updated), 0 ),
		gConn.Escape( item.Author ),
		gConn.Escape( item.Id ) )

	if err != nil {
		panic(err)
	}
	
	self.entryIds = append(self.entryIds, item.Id )
}

func (self SQLImporter) ReadFeedItems(items []FeedItem) {

	//Assert that the first 5 letters are "feed/"
	for _, item := range items {
		self.ReadFeedItem(item)
	}

}

func (self SQLImporter) OnStarred(feed *FeedItems) {
	self.ReadFeedItems(feed.Items)
}

func (self SQLImporter) OnLiked(feed *FeedItems) {
	self.ReadFeedItems(feed.Items)
}

func (self SQLImporter) OnShared(feed *FeedItems) {
	self.ReadFeedItems(feed.Items)
}

func SQLImport(userId uint32, file string) (retErr error ){
	importer := SQLImporter{userId, nil, make(map[string]uint32), make(map[string]uint32), make([]string, 0)}
	var err error
	
	importer.transaction, err = gConn.Begin()
	
	if err != nil {
		return err
	}
	
	defer func() {
        if e := recover(); e != nil {
            importer.transaction.Rollback()
            retErr = e.(error)
        }
    }()

	ImportGReader(importer, file)
	
	importer.transaction.Commit()

	return nil

}
