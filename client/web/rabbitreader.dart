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
  List<Feed> feeds = new List<Feed>();
  FeedEntryListWidget entries = new FeedEntryListWidget();
  
  void setFeedProdiver(FeedProvier provider){
    entries.setFeedProdiver(provider);
  }
}



class Feed {
  int id;
  String title;
  String link;
  String description;
  int lastUpdate;
  String group;
  
  Feed(this.id, this.title, this.link, this.description, this.lastUpdate, this.group);
  
}

void main() {

  HttpRequest.getString("http://localhost:8080/home").then((t){
    Map parsed = parse(t);
    
    List<Feed> newFeeds = parsed["Feeds"].map((Map feed){
      return new Feed( feed["Id"], feed["Title"], feed["Link"], feed["Description"], feed["LastUpdate"], feed["Group"] );
    } ).toList();
    
    reader.feeds.addAll(newFeeds);
    
    FeedTreeWidget widget = new FeedTreeWidget( newFeeds );
    reader.setFeedProdiver(new FeedProvier());
    
    ui.RootPanel.get("feedList").add(widget);
    ui.RootPanel.get("entryBody").add(reader.entries);
  });
  
}
