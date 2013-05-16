package rreader

import (
	_ "database/sql"
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
	
	_, res, err = self.transaction.Query("INSERT IGNORE INTO `user_feed`(`user_id`,`feed_id`,`newest_read`,`unread_items`,`group`) VALUES (%d, %d, %d, %d,'%s')",
		self.userId, 
		feedId, 
		time.Now().Unix(), 
		0,
		gConn.Escape(group) )
		
	if err != nil {
		panic(err)
	}	
	
}

func (self SQLImporter) ReadFeedItem(item FeedItem) uint64 {
	//Assert that the first 5 letters are "feed/"
	if !strings.HasPrefix(item.Origin.StreamId, "feed/") {
		//Ignoring unkown items for now, such as 'pop/topic/top/language/en' found in my feed (youtube video)
		//TODO: Fill the edge cases of unkown stream id.		
		//panic( errors.New("Unkown type of feed '" + item.Origin.StreamId + "'!") )
	}
	
	//Check if we already added the item.
	for _, id := range self.entryIds {
		if id == item.Id {
			return 0
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
	
			_, res, err := self.transaction.Query("INSERT INTO `feed`(`title`,`description`,`link`,`last_update`,`feedURL`,`disabled`) VALUES ('%s','%s','%s',%d,'%s',1)",
				"",
				"",
				feedUrl,
				0,
				feedUrl)
	
			if err != nil {
				panic(err)
			}
	
			feedId = uint32(res.InsertId())
			
			_, res, err = self.transaction.Query("INSERT IGNORE INTO `user_feed`(`user_id`,`feed_id`,`newest_read`,`unread_items`,`active`) VALUES (%d, %d, %d,0,0)",
				self.userId, 
				feedId, 
				time.Now().Unix() )
				
			if err != nil {
				panic(err)
			}	
		}
		
		//Update the feedId for future objects
		self.feedIds[feedUrl] = feedId
	}
	
	content := item.Summary.Content
	
	if len(item.Content.Content) > len(content) {
		content = item.Content.Content
	}
	
	_, res, err := self.transaction.Query("INSERT IGNORE INTO `feed_entry`(`feed_id`,`title`,`content`,`link`,`published`,`updated`,`author`,`guid`) VALUES (%d,'%s','%s','%s',%d,%d,'%s','%s')",
		feedId,
		gConn.Escape(item.Title),
		gConn.Escape(content),
		gConn.Escape( item.Alternate[0].Href ),
		int64(item.Published),
		int64(item.Updated),
		gConn.Escape( item.Author ),
		gConn.Escape( item.Id ) )
	
	if err != nil {
		panic(err)
	}
	
	entryId := res.InsertId()
	
	self.entryIds = append(self.entryIds, item.Id )
	
	return entryId
}

func (self SQLImporter) OnStarred(feed *FeedItems) {
	for _, item := range feed.Items {
		entryId := self.ReadFeedItem(item)
		
		if entryId != 0 {
			_, _, err := self.transaction.Query("INSERT IGNORE INTO `user_entry_label`(`user_id`,`feed_entry_id`,`label`) VALUES (%d,%d,'star')",
				self.userId, 
				entryId )
			
			if err != nil {
				panic(err)
			}
		}
	}
}

func (self SQLImporter) OnLiked(feed *FeedItems) {
	for _, item := range feed.Items {
		self.ReadFeedItem(item)
	}
}

func (self SQLImporter) OnShared(feed *FeedItems) {
	for _, item := range feed.Items {
		self.ReadFeedItem(item)
	}
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
