package rreader

import (
	"fmt"
	//"github.com/stretchrcom/goweb/goweb"
	"net/http"
	"time"
	"encoding/json"
	"strconv"
	"github.com/ziutek/mymysql/mysql"
)

type HomeView struct {
	Feeds []FeedViewItem
}

type FeedViewItem struct {
	Id int
	Title string
	Link string
	Description string
	LastUpdate int64
	Group string
}

type ChannelView struct {
	Items []ChannelViewItem
}

type ChannelViewItem struct {
	Id int
	Title string
	Published int64
	Link string
	Author string
	FeedTitle string
	FeedId int
}
  
func serveHome(w http.ResponseWriter, r *http.Request) { 

	var userId uint32 = 1
	rows, _, err := GetConnection().Query("SELECT `id`,`title`,`link`,`description`,`last_update`,`user_id`,`group` FROM home_view WHERE user_id=%d", userId)
	
	if err != nil {
		panic(err)
	}
	
	feeds := make([]FeedViewItem, len(rows) )
	
	for id, row := range rows {
		feeds[id] = FeedViewItem{row.Int(0),row.Str(1),row.Str(2),row.Str(3), row.Time(4, time.Local).Unix(), row.Str(6) }
	}
	
	b, err := json.Marshal(HomeView{feeds})
	
	if err != nil {
		panic(err)
	}
	
	fmt.Fprintf(w, string(b) )
	//c.Format = goweb.JSON_FORMAT
	//c.RespondWithData(HomeView{feeds})
}

func serveFeedItems(w http.ResponseWriter, r *http.Request) { 
	var userId uint32 = 1
	searchQuery := fmt.Sprintf("userid=%d", userId )
	
	group := r.FormValue("group")
	feed := r.FormValue("feed")
	start, err := strconv.ParseInt( r.FormValue("start"), 10, 64 )
	
	if err != nil {
		start = 0
	}
	
	if group != "" {
		searchQuery = fmt.Sprintf("%s AND `group`='%s'", searchQuery, gConn.Escape(group) )
	} else if feed != "" {
		feedId, err := strconv.ParseInt( feed, 10, 64 )
	
		if err != nil {
			panic(err)
		}
	
		searchQuery = fmt.Sprintf("%s AND `feedid`=%d", searchQuery, feedId )
	}
	
	rows, _, err := GetConnection().Query("SELECT `id`,`title`,`published`,`link`,`author`,`feedtitle`,`feedid` FROM `entrylist` WHERE %s ORDER BY `published` DESC LIMIT %d,100", searchQuery, start)
	
	if err != nil {
		panic(err)
	}
	
	feeds := make([]ChannelViewItem, len(rows) )
	
	for id, row := range rows {
		published := row.Time(2, time.Local).Unix()
		feeds[id] = ChannelViewItem{row.Int(0),row.Str(1),published,row.Str(3),row.Str(4),row.Str(5),row.Int(6)}
	}
	
	b, err := json.Marshal(ChannelView{feeds})
	
	if err != nil {
		panic(err)
	}
	
	fmt.Fprintf(w, string(b) )
	
	//c.Format = goweb.JSON_FORMAT
	//c.RespondWithData(ChannelView{feeds})
}

type FeedEntryModel struct {
	Id int
	FeedId int
	Title string
	Content string
	Comments string
	Published int64
	Updated int64
	Author string
	Link string
}

func serveGetItem(w http.ResponseWriter, r *http.Request) { 
	id, err := strconv.ParseInt( r.FormValue("id"), 10, 64 )
	
	if err != nil {
		panic(err)
	}
	
	row, _, err := GetConnection().QueryFirst("SELECT `id`,`feed_id`,`title`,`content`,`comments`,`published`,`updated`,`author`,`link` FROM `feed_entry` WHERE id=%d", id)
	
	if err != nil {
		panic(err)
	}
	
	published := row.Time(5, time.Local).Unix()
	update := row.Time(6, time.Local).Unix() 

	model := FeedEntryModel{row.Int(0),row.Int(1),row.Str(2),row.Str(3),row.Str(4), published, update, row.Str(7),row.Str(8)}
	
	b, err := json.Marshal(model)
	
	if err != nil {
		panic(err)
	}
	
	fmt.Fprintf(w, string(b) )
	
	//c.Format = goweb.JSON_FORMAT
	//c.RespondWithData(model)
}

func updatePriorities( transaction mysql.Transaction, userId int, newPriorities map[string]GroupInfo ) error {
	
	for feedIdStr, priority := range newPriorities {
		feedId, err := strconv.ParseInt( feedIdStr, 10, 64 )
		
		if err != nil {
			return err
		}
		
		_, _, err = transaction.Query("UPDATE `user_feed` SET `priority`=%d, `group`='%s'  WHERE feed_id=%d AND user_id=%d", 
			priority.Priority,
			gConn.Escape(priority.Group), 
			feedId, 
			userId )
		
		if err != nil {
			return err
		}
	}
	
	return nil
}

type GroupInfo struct {
	Priority int
	Group string
}

func serveUpdateOrder(w http.ResponseWriter, r *http.Request) { 
	if r.Method != "POST" {
		w.WriteHeader(400)
		fmt.Fprint(w, "Not a post request.");
		return;
	}
	
	userId := 1
	decoder := json.NewDecoder(r.Body)
	var newPriorities map[string]GroupInfo = make(map[string]GroupInfo)   
	
	err := decoder.Decode(&newPriorities)
    if err != nil {
        panic(err)
    }
    
    transaction, err := gConn.Begin()
	if err != nil {
		panic(err)
	}
	
	err = updatePriorities( transaction, userId, newPriorities )

	if err != nil {
		transaction.Rollback()
		panic(err)
	}
	
	transaction.Commit()
}


func StartWebserver() {
	
	http.HandleFunc("/home", serveHome)
	http.HandleFunc("/feed", serveFeedItems)
	http.HandleFunc("/item", serveGetItem)
	http.HandleFunc("/updateOrder", serveUpdateOrder)
	http.Handle("/", http.StripPrefix("/", http.FileServer(http.Dir("C:/Users/Nican/dart/RabbitReader/web"))))
	
	//goweb.MapFunc("/home", serveHome)
	//goweb.MapFunc("/feed/{page}", serveFeedItems )
	//goweb.MapFunc("/item/{id}", serveGetItem )
	//goweb.MapStatic("*", "C:/Users/Nican/dart/RabbitReader/web/out")
	
	http.ListenAndServe(":8080", nil) 
	//goweb.ConfigureDefaultFormatters()
	//goweb.ListenAndServe(":8080")

}
