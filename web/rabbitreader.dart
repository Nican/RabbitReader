library RabbitReader;

import 'dart:html';
import 'dart:json';
import 'dart:async';
import 'dart:uri';
import 'package:dart_web_toolkit/ui.dart' as ui;
import 'package:dart_web_toolkit/event.dart' as event;

part 'menu.dart';
part 'feedlist.dart';

RabbitReader reader = new RabbitReader();

class RabbitReader {
  StreamController<Feed> onFeedAddedController = new StreamController<Feed>();
  Stream<Feed> get onFeedAdded => onFeedAddedController.stream;
  
  List<Feed> feeds = new List<Feed>();
  
  FeedEntryListWidget entries = new FeedEntryListWidget();
  
  void setFeedProdiver(FeedEntryProvier provider){
    entries.setFeedProdiver(provider);
  }
  
  void newFeedData( Map feedData ){
    Feed feed = getFeedById(feedData["Id"]);
    
    if(feed != null ){
      feed.setData(feedData);
      return;
    }
    
    feed = new Feed(feedData["Id"]);
    feed.setData(feedData);
    addFeed(feed);
  }
  
  void addFeed(Feed feed){
    this.feeds.add(feed);
    onFeedAddedController.add(feed);
  }
  
  Feed getFeedById(int id){
    return feeds.firstWhere((Feed feed){ return feed.id == id; }, orElse: (){ return null;} );
  }
}

class Feed {
  int id;
  String title;
  String link;
  String description;
  int lastUpdate;
  String group;
  int unreadItems;
  
  StreamController<Feed> onUpdateController = new StreamController<Feed>();
  Stream<Feed> get onUpdate => onUpdateController.stream;
  
  Feed(this.id);
  
  void setData(Map feedData){
    this.title = feedData["Title"]; 
    this.link = feedData["Link"]; 
    this.description = feedData["Description"]; 
    this.lastUpdate = feedData["LastUpdate"]; 
    this.group = feedData["Group"]; 
    this.unreadItems = feedData["Unread"];
    
    this.fireUpdate();
  }
  
  void fireUpdate(){
    onUpdateController.add(this);
  }
  
}

class FeedEntryProvier {
  
  int itemsPerPage = 100;
  String query;
  
  FeedEntryProvier(){
    query = "";
  }
  
  FeedEntryProvier.byGroup( String group ){
    query = "group=${group}";
  }
  
  FeedEntryProvier.byFeed( Feed feed ){
    query = "feed=${feed.id}";
  }
  
  FeedEntryProvier.byStarred() {
    query = "starred=1";
  }
  
  
  Future<List<FeedEntry>> getPage({ int page: 0 }){
    Completer<List<FeedEntry>> completer = new Completer();
    String href = "http://localhost:8080/feed?${query}&start=${page * itemsPerPage}";
    
    HttpRequest.getString(href).then((t){
      Map parsed = parse(t);
      
      List<FeedEntry> newFeeds = parsed["Items"].map((Map feedItem){
        DateTime time = new DateTime.fromMillisecondsSinceEpoch( feedItem["Updated"] * 1000 );
        Feed feed = reader.getFeedById(feedItem["FeedId"]);    
        List<String> labels = feedItem["Labels"].split(",");
        
        return new FeedEntry( 
            feedItem["Id"], 
            feedItem["Title"], 
            time, 
            feedItem["Link"], 
            feedItem["Author"], 
            feed, 
            feedItem["IsRead"] > 0,
            labels);
        
      } ).toList();
      
      completer.complete( newFeeds );
    });
   
    return completer.future;
  }
  
}

class FeedEntry {
  int id;
  String title;
  DateTime published;
  String link;
  String author;
  Feed feed;
  bool isRead;
  List<String> labels;
  String content;
  
  StreamController<FeedEntry> onUpdateController = new StreamController<FeedEntry>();
  Stream<FeedEntry> get onUpdate => onUpdateController.stream;
  
  FeedEntry(this.id, this.title, this.published, this.link, this.author, this.feed, this.isRead, this.labels );
  
  String _pad(String input, int characters){
    while( input.length < characters ){
      input = "0" + input;
    }
    return input;
  }
  
  String getFormattedTime(){
    DateTime today = new DateTime.now();
    
    
    if( today.day == published.day && today.month == published.month && today.year == published.year){
      return "${_pad(published.hour.toString(),2)}:${_pad(published.minute.toString(),2)}";
    }
    
    return "${published.month}/${published.day}/${published.year}";
  }
  
  void markAsRead(){
    if(isRead)
      return;
    
    isRead = true;
    onUpdateController.add(this);
    
    feed.unreadItems -= 1;
    feed.fireUpdate();
  }
  
  Future<bool> updateLabels(){
    
    var completer = new Completer<bool>();
    FormData data = new FormData();
    data.append("id", id.toString() );
    data.append("labels", labels.join(",") );
    
    HttpRequest.request("http://localhost:8080/updateLabels", method: "POST", sendData: data).then((HttpRequest request){
      completer.complete(true);      
    }, onError: (e){
      completer.completeError(e);
    });
    
    return completer.future;
  }
  
  Future<String> getContent(){
    Completer<String> completer = new Completer();
    
    HttpRequest.getString("http://localhost:8080/item?id=${id}").then((t){
      Map parsed = parse(t);
      
      this.content = parsed["Content"];
      
      completer.complete(this.content);
    });
    
    return completer.future;
  }
}

void requestForUpdate(){
  HttpRequest.getString("http://localhost:8080/home?update=1").then((t){
    Map parsed = parse(t);
    parsed["Feeds"].forEach(reader.newFeedData);
  });
}

void main() {
  ui.RootPanel.get("feedList").add(new Menu());
  ui.RootPanel.get("entryBody").add(reader.entries);
  
  HttpRequest.getString("http://localhost:8080/home").then((t){
    Map parsed = parse(t);
    parsed["Feeds"].forEach(reader.newFeedData);
    
    requestForUpdate();
    
    reader.setFeedProdiver(new FeedEntryProvier());
  });
  
}
