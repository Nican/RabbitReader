package rreader

import (
	"fmt"
	//"github.com/stretchrcom/goweb/goweb"
	"encoding/json"
	"github.com/ziutek/mymysql/mysql"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type HomeView struct {
	Feeds []FeedViewItem
}

type FeedViewItem struct {
	Id          int
	Title       string
	Link        string
	Description string
	LastUpdate  int64
	Group       string
	Unread      int
	Active 		int
}

type ChannelView struct {
	Items []ChannelViewItem
}

type ChannelViewItem struct {
	Id        int
	Title     string
	Published string
	Updated   int64
	Link      string
	Author    string
	FeedTitle string
	FeedId    int
	IsRead    int
	Labels    string
}

type ErrorResponse struct {
	ErrStr string
}

func respondError( w http.ResponseWriter, errStr string ){
	w.WriteHeader( 500 ) //Internal server error	
	fmt.Fprint(w, errStr )
}

func serveHome(w http.ResponseWriter, r *http.Request) {
	if r.FormValue("update") != "" {
		UpdateFeeds(60)
	}

	conn := GetConnection().Clone()

	if err := conn.Connect(); err != nil {
		respondError( w, err.Error() )
		return
	}

	defer conn.Close()
	
	var userId uint32 = 1
	rows, _, err := conn.Query("SELECT `id`,`title`,`link`,`description`,`last_update`,`user_id`,`group`,`unread`,`active` FROM home_view WHERE user_id=%d", userId)
	
	if err != nil {
		respondError( w, err.Error() )
		return
	}

	feeds := make([]FeedViewItem, len(rows))

	for id, row := range rows {
		feeds[id] = FeedViewItem{row.Int(0), row.Str(1), row.Str(2), row.Str(3), row.Int64(4), row.Str(6), row.Int(7), row.Int(8)}
	}

	b, err := json.Marshal(HomeView{feeds})

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	fmt.Fprint(w, string(b))
	//c.Format = goweb.JSON_FORMAT
	//c.RespondWithData(HomeView{feeds})
}

func getFeedsQueryFromForm(r *http.Request) (string, error) {
	group := r.FormValue("group")
	feed := r.FormValue("feed")
	starred := r.FormValue("starred")

	if group != "" {
		return fmt.Sprintf("`group`='%s'", gConn.Escape(group)), nil
	} else if feed != "" {
		feedId, err := strconv.ParseInt(feed, 10, 64)

		if err != nil {
			return "", err
		}

		return fmt.Sprintf("`feedid`=%d", feedId), nil
	} else if starred != "" {
		return fmt.Sprintf("`label`='star'"), nil
	}

	return "", nil
}

func serveFeedItems(w http.ResponseWriter, r *http.Request) {
	var userId uint32 = 1
	searchQuery := fmt.Sprintf("userid=%d", userId)
	start, err := strconv.ParseInt(r.FormValue("start"), 10, 64)

	if err != nil {
		start = 0
	}
	
	extraSearch, err := getFeedsQueryFromForm(r)
	
	if err != nil {
		respondError( w, err.Error() ) 
		return
	}
	
	if extraSearch != "" {
		searchQuery = fmt.Sprintf("%s AND %s", searchQuery, extraSearch )
	}

	conn := GetConnection().Clone()

	if err := conn.Connect(); err != nil {
		respondError( w, err.Error() )
		return
	}

	defer conn.Close()

	rows, _, err := conn.Query("SELECT `id`,`title`,`published`,`updated`,`link`,`author`,`feedtitle`,`feedid`,`is_read`,`label` FROM `entrylist` WHERE %s ORDER BY `updated` DESC LIMIT %d,100", searchQuery, start)

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	feeds := make([]ChannelViewItem, len(rows))

	for id, row := range rows {
		feeds[id] = ChannelViewItem{row.Int(0), row.Str(1), row.Str(2), row.Int64(3), row.Str(4), row.Str(5), row.Str(6), row.Int(7), row.Int(8), row.Str(9) }
	}

	b, err := json.Marshal(ChannelView{feeds})

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	fmt.Fprint(w, string(b))

	//c.Format = goweb.JSON_FORMAT
	//c.RespondWithData(ChannelView{feeds})
}

type FeedEntryModel struct {
	Content string
}

func serveGetItem(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.FormValue("id"), 10, 64)
	userId := 1

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	conn := GetConnection().Clone()

	if err := conn.Connect(); err != nil {
		respondError( w, err.Error() )
		return
	}

	defer conn.Close()

	rows, _, err := conn.Query("SELECT `content` FROM `feed_entry` WHERE id=%d", id)

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	if len(rows) == 0 {
		fmt.Fprint(w, "{\"error\": \"Could not find entry\"}")
		return
	}

	row := rows[0]
	b, err := json.Marshal(FeedEntryModel{row.Str(0)})

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	//TODO:The update and replace statments should be in a transaction 
	//TODO: Only insert into user_feed_readitems when the items is newer than the user_feeds.newest_read  
	_, _, err = conn.QueryFirst("REPLACE INTO `user_feed_readitems`(user_id,entry_id) VALUES (%d,%d)", userId, id)

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}
	/*
	_, _, err = GetConnection().QueryFirst("UPDATE user_feed SET unread_items=GREATEST(unread_items-1,0) WHERE user_id=%d AND feed_id=%d", userId, feedId)

	if err != nil {
		panic(err)
	}
	*/
	//TODO: Extremelly inneficient; Make better method
	_, _, err = conn.QueryFirst("CALL update_unread()")

	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	fmt.Fprint(w, string(b))
}

func serveUpdateItemLabels(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		w.WriteHeader(400)
		fmt.Fprint(w, "Not a post request.")
		return
	}

	conn := GetConnection().Clone()

	if err := conn.Connect(); err != nil {
		respondError( w, err.Error() )
		return
	}

	defer conn.Close()
	
	entryId, err := strconv.ParseInt(r.FormValue("id"), 10, 64)
	labels := conn.Escape( r.FormValue("labels") )
	userId := 1

	if err != nil {
		respondError( w, err.Error() )
		return
	}	
	
	getQuery := func() string {
		if labels == "" {
			return fmt.Sprintf("DELETE FROM `user_entry_label` WHERE `user_id`=%d AND `feed_entry_id`=%d", userId, entryId )
		}
		return fmt.Sprintf("INSERT IGNORE INTO `user_entry_label`(`user_id`,`feed_entry_id`,`label`) VALUES (%d,%d,'%s')", userId, entryId, labels )
	}
	
	_, _, err = conn.Query(getQuery())

	if err != nil {
		respondError( w, err.Error() )
		return
	}
	
	fmt.Fprint(w, "{\"success\":1}")
	
}

func updatePriorities(transaction mysql.Transaction, userId int, newPriorities map[string]GroupInfo) error {

	for feedIdStr, priority := range newPriorities {
		feedId, err := strconv.ParseInt(feedIdStr, 10, 64)

		if err != nil {
			return err
		}

		_, _, err = transaction.Query("UPDATE `user_feed` SET `priority`=%d, `group`='%s'  WHERE feed_id=%d AND user_id=%d",
			priority.Priority,
			gConn.Escape(priority.Group),
			feedId,
			userId)

		if err != nil {
			return err
		}
	}

	return nil
}

type GroupInfo struct {
	Priority int
	Group    string
}

func serveUpdateOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		w.WriteHeader(400)
		fmt.Fprint(w, "Not a post request.")
		return
	}

	userId := 1
	decoder := json.NewDecoder(r.Body)
	var newPriorities map[string]GroupInfo = make(map[string]GroupInfo)

	err := decoder.Decode(&newPriorities)
	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	conn := GetConnection().Clone()

	if err := conn.Connect(); err  != nil {
		respondError( w, err.Error() )
		return
	}

	defer conn.Close()

	transaction, err := conn.Begin()
	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	err = updatePriorities(transaction, userId, newPriorities)

	if err != nil {
		transaction.Rollback()
		respondError( w, err.Error() ) 
		return
	}

	transaction.Commit()
}

func serveMarkRead(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		w.WriteHeader(400)
		fmt.Fprint(w, "Not a post request.")
		return
	}

	var userId uint32 = 1
	
	decoder := json.NewDecoder(r.Body)
	var readFeedsIds []int

	err := decoder.Decode(&readFeedsIds)
	if err != nil {
		respondError( w, err.Error() ) 
		return
	}
	
	if len(readFeedsIds) == 0 {
		respondError( w, "The array of feeds to mark as read is empty." ) 
		return
	}
	
	readFeeds := []string {}
	for _, id := range(readFeedsIds) {
		readFeeds = append(readFeeds, strconv.Itoa( id ) )
	}

	conn := GetConnection().Clone()

	if err := conn.Connect(); err  != nil {
		respondError( w, err.Error() )
		return
	}

	defer conn.Close()

	_, _, err = conn.Query("UPDATE `user_feed` SET `newest_read`=NOW(), `unread_items`=0  WHERE user_id=%d AND feed_id IN (%s)",
			userId,
			strings.Join( readFeeds, "," ) )
			
	if err != nil {
		respondError( w, err.Error() ) 
		return
	}
	
	_, _, err = conn.Query("DELETE `user_feed_readitems` FROM `user_feed_readitems` INNER JOIN `feed_entry` ON `user_feed_readitems`.`entry_id` = `feed_entry`.`id` WHERE user_feed_readitems.`user_id`=%d AND `feed_entry`.`feed_id` IN (%s)",
			userId,
			strings.Join( readFeeds, "," ) )
			
	if err != nil {
		respondError( w, err.Error() ) 
		return
	}
	
	fmt.Fprint(w, "{\"success\":1}")
}


func serveAddFeed(w http.ResponseWriter, r *http.Request) {

	if r.Method != "POST" {
		w.WriteHeader(400)
		fmt.Fprint(w, "Not a post request.")
		return
	}

	var userId uint32 = 1
	conn := GetConnection().Clone()
	
	var request struct {
		Uri string
	}
	
	decoder := json.NewDecoder(r.Body)

	err := decoder.Decode(&request)
	if err != nil {
		respondError( w, err.Error() ) 
		return
	}

	if err := conn.Connect(); err  != nil {
		respondError( w, err.Error() )
		return
	}

	defer conn.Close()

	transaction, err := gConn.Begin()
	
	if err != nil {
		respondError( w, err.Error() )
		return
	}
	
	rows, _, err := transaction.Query("SELECT `id` FROM `feed` WHERE `feedURL`='%s'", request.Uri)
	var feedId uint64 = 0

	if err != nil {
		transaction.Rollback()
		respondError( w, err.Error() )
		return
	}

	if len(rows) > 0 {
		feedId = rows[0].Uint64(0)
	} else {

		feedId, err = AddFeed(transaction, request.Uri)
	
		if err != nil {
			transaction.Rollback()
			respondError( w, err.Error() )
			return
		}
	}

	_, _, err = transaction.Query("INSERT INTO `user_feed`(`user_id`,`feed_id`,`newest_read`,`unread_items`,`active`) VALUES (%d, %d, %d,0,0)",
		userId, 
		feedId, 
		time.Now().Unix() )

	if err != nil {
		transaction.Rollback()
		respondError( w, err.Error() )
		return
	}

	transaction.Commit()
	fmt.Fprint(w, "{\"success\":1}")
}

func StartWebserver() {

	http.HandleFunc("/home", serveHome )
	http.HandleFunc("/feed", serveFeedItems )
	http.HandleFunc("/item", serveGetItem )
	http.HandleFunc("/updateLabels", serveUpdateItemLabels )
	http.HandleFunc("/updateOrder", serveUpdateOrder )
	http.HandleFunc("/markRead", serveMarkRead )
	http.HandleFunc("/add", serveAddFeed )
	http.Handle("/", http.StripPrefix("/", http.FileServer(http.Dir("web"))) )

	http.ListenAndServe(":8080", nil)
}
