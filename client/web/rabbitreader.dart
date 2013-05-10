library RabbitReader;

import 'dart:html';
import 'dart:json';
import 'dart:async';
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
  
  void setFeedProdiver(FeedProvier provider){
    entries.setFeedProdiver(provider);
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
  
  Feed(this.id, this.title, this.link, this.description, this.lastUpdate, this.group, this.unreadItems);
  
  void fireUpdate(){
    onUpdateController.add(this);
  }
  
}

void main() {
  FeedTreeWidget feedTree = new FeedTreeWidget();  
  ui.RootPanel.get("feedList").add(feedTree);
  ui.RootPanel.get("entryBody").add(reader.entries);
  
  

  HttpRequest.getString("http://localhost:8080/home").then((t){
    Map parsed = parse(t);
    
    List<Feed> newFeeds = parsed["Feeds"].map((Map feed){
      return new Feed( feed["Id"], feed["Title"], feed["Link"], feed["Description"], feed["LastUpdate"], feed["Group"], feed["Unread"] );
    } ).toList();
    
    newFeeds.forEach(reader.addFeed);
    reader.setFeedProdiver(new FeedProvier());
  });
  
}
