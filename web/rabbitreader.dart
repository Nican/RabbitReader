library RabbitReader;

import 'dart:html';
import 'dart:json';
import 'dart:async';
import 'dart:uri';
import 'package:dart_web_toolkit/ui.dart' as ui;
import 'package:dart_web_toolkit/event.dart' as event;
import 'package:dart_web_toolkit/util.dart' as util;

part 'menu.dart';
part 'feedlist.dart';

RabbitReader reader = new RabbitReader();

class RabbitReader {
  StreamController<Feed> onFeedAddedController = new StreamController<Feed>();
  Stream<Feed> get onFeedAdded => onFeedAddedController.stream;
  FeedList feedList = new FeedList();
  
  List<Feed> feeds = new List<Feed>();
  
  void setFeedProdiver(FeedEntryProvier provider){
    feedList.setFeedProdiver(provider);
  }
  
  Future<String> updateFeeds({update: false}){
    String query = update ? "?update=1" : "";
    
    Future future = HttpRequest.getString("/home${query}");
    
    return future.then((t){
      Map parsed = parse(t);
      parsed["Feeds"].forEach(reader.newFeedData);
    });
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
  bool active;
  
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
    this.active = feedData["Active"] > 0;
    
    this.fireUpdate();
  }
  
  void fireUpdate(){
    onUpdateController.add(this);
  }
  
}

class FeedEntryProvier {
  int itemsPerPage = 100;
  
  FeedEntryProvier();
  
  Future<List<FeedEntry>> getPage({ int page: 0 }){
    Completer<List<FeedEntry>> completer = new Completer();
    String href = "/feed?${getQuery()}&start=${page * itemsPerPage}";
    
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
  
  String getQuery(){
    return "";
  }
 
  Future<bool> markRead(){
    Future<bool> future = _markRead(reader.feeds);
    
    
    
    return future;
  }
  
  Future<bool> _markRead(List<Feed> feeds){
    Completer completer = new Completer();
    
    List feedIds = feeds.map((Feed feed){ return feed.id; }).toList();
    print(feedIds);
    String jsonData = stringify(feedIds);
    
    HttpRequest.request("/markRead", method: "POST", sendData: jsonData).then((HttpRequest request){
      completer.complete(true);      
    }, onError: (e){
      completer.completeError(e);
    });
    
    return completer.future;
  }
}


class FeedEntryGroupProvier extends FeedEntryProvier{
  String group;
  
  FeedEntryGroupProvier(this.group);
  
  String getQuery(){
    return "group=${group}";
  }
  
  Future<bool> markRead(){
    return _markRead(reader.feeds.where(
        (Feed feed){ return feed.group == group; }));
  }
}

class FeedEntryFeedProvier extends FeedEntryProvier{
  Feed feed;
  
  FeedEntryFeedProvier(this.feed);
  
  String getQuery(){
    return "feed=${feed.id}";
  }
  
  Future<bool> markRead(){
    var feeds = new List<Feed>();
    feeds.add(feed);
    return _markRead(feeds);
  }
}


class FeedEntryStarredProvier extends FeedEntryProvier{
  FeedEntryStarredProvier();
  
  String getQuery(){
    return "starred=1";
  }
  
  Future<bool> markRead(){
    Completer completer = new Completer();
    
    completer.completeError(new Exception("Can not mark starred items as read"));
    
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
    
    HttpRequest.request("/updateLabels", method: "POST", sendData: data).then((HttpRequest request){
      completer.complete(true);      
    }, onError: (e){
      completer.completeError(e);
    });
    
    return completer.future;
  }
  
  Future<String> getContent(){
    Completer<String> completer = new Completer();
    
    HttpRequest.getString("/item?id=${id}").then((t){
      Map parsed = parse(t);
      
      this.content = parsed["Content"];
      
      completer.complete(this.content);
    });
    
    return completer.future;
  }
}

void main() {
  ui.RootPanel.get("feedList").add(new Menu());
  ui.RootPanel.get("entryBody").add(reader.feedList);
  
  reader.updateFeeds(update: false).then((e){
    reader.setFeedProdiver(new FeedEntryProvier());
    reader.updateFeeds(update: true);
  });
  
}
