package rreader

import (
	"archive/zip"
	"encoding/xml"
	"encoding/json"
	"strings"
)

type GReader interface {
	OnSubscription(subscription *Subscription, group string)
	OnStarred(feed *FeedItems)
	OnLiked(feed *FeedItems)
	OnShared(feed *FeedItems)
}

type Subscriptions struct {
	Children          []Subscription   `xml:"outline"`

}

type Subscription struct {
	Text          string   `xml:"text,attr"`
	Title         string   `xml:"title,attr"`
	Type   		  string   `xml:"type,attr"`
	HtmlUrl       string   `xml:"htmlUrl,attr"`
	XmlUrl        string   `xml:"xmlUrl,attr"`
	Children      []Subscription   `xml:"outline"`
}

type FeedItems struct {
	Id string
	Title string
	Author string
	Items []FeedItem
}

type FeedItem struct {
	Title string
	Id string
	Categories []string
	Published int
	Updated int
	Author string
	
	Summary struct {
		Direction string
		Content string
	}
	
	Content struct {
		Direction string
		Content string
	}

	Alternate []StarrtedItemAlternate
	Replies []StarrtedItemAlternate
	
	Origin struct {
		StreamId string
		Title string
		HtmlUrl string
	}
}

type StarrtedItemAlternate struct {
	Href string
	Type string
}


func readSubscription( reader GReader, subscription Subscription, group string ) {	

	if subscription.Type == "rss" {
		reader.OnSubscription( &subscription, group )
	}
	
	for _, item := range subscription.Children {
		readSubscription( reader, item, subscription.Title )
	}
}

func readSubscriptions( reader GReader, f *zip.File ) {	
	rc, err := f.Open()
	
    if err != nil {
       	panic( err )
    }
    
	var subscriptions struct {
		Subscriptions Subscriptions `xml:"body"`
	}
	
	
	xmlDecoder := xml.NewDecoder(rc)
	err = xmlDecoder.Decode(&subscriptions)
	
	if err != nil {
		panic(err)
	}

	for _, item := range subscriptions.Subscriptions.Children {
		readSubscription( reader, item, "" )
	}
}

func readJson(f *zip.File) FeedItems {
	rc, err := f.Open()
    
    if err != nil {
       	panic( err )
    }
    
    dec := json.NewDecoder(rc)
    var feed FeedItems
    
    if err = dec.Decode(&feed); err != nil {
    	panic( err )
    } 
    
    return feed
}

func readStarred( reader GReader, f *zip.File ) {
    json := readJson(f)
    reader.OnStarred( &json )
}

func readLiked( reader GReader, f *zip.File ) {
    json := readJson(f)
    reader.OnLiked( &json )
}

func readShared( reader GReader, f *zip.File ) {
    json := readJson(f)
    reader.OnShared( &json )
}


func ImportGReader(reader GReader, filePath string ) {
	r, err := zip.OpenReader(filePath)
	
	if err != nil {
	    panic( err )
	}
	defer r.Close()
	
	for _, f := range r.File {
		if strings.HasSuffix( f.Name, "subscriptions.xml") {
			readSubscriptions( reader, f )
		}
		
		if strings.HasSuffix( f.Name, "starred.json") {
			readStarred( reader, f )
		}
		
		if strings.HasSuffix( f.Name, "shared.json") {
			readShared( reader, f )
		}
		
		if strings.HasSuffix( f.Name, "liked.json") {
			readLiked( reader, f )
		}
	
    	//fmt.Printf("File: %s\n", f.Name)
    }
}
