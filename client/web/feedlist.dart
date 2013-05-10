part of RabbitReader;


class FeedItemList {
  int id;
  String title;
  DateTime published;
  String link;
  String author;
  Feed feed;
  bool isRead;
  
  StreamController<FeedItemList> onUpdateController = new StreamController<FeedItemList>();
  Stream<FeedItemList> get onUpdate => onUpdateController.stream;
  
  FeedItemList(this.id, this.title, this.published, this.link, this.author, this.feed, this.isRead );
  
  String getFormattedTime(){
    DateTime today = new DateTime.now();
    
    
    if( today.day == published.day && today.month == published.month && today.year == published.year){
      return "${published.hour}:${published.minute}";
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
  
  Future<FeedEntryModel> getEntry(){
    Completer<FeedEntryModel> completer = new Completer();
    
    HttpRequest.getString("http://localhost:8080/item?id=${id}").then((t){
      Map parsed = parse(t);
      
      DateTime updated = new DateTime.fromMillisecondsSinceEpoch( parsed["Updated"] * 1000 );
      
      FeedEntryModel model = new FeedEntryModel(
          parsed["Id"],
          parsed["FeedId"],
          parsed["Title"],
          parsed["Content"],
          parsed["Published"],
          updated,
          parsed["Author"],
          parsed["Link"]      
      );
      
      completer.complete(model);
    });
    
    return completer.future;
  }
}

class FeedEntryModel {
  int id;
  int feedId;
  String title;
  String content;
  String published;
  DateTime updated;
  String author;
  String link;
  
  FeedEntryModel(this.id,this.feedId,this.title,this.content,this.published,this.updated,this.author,this.link);
}


class FeedProvier {
  
  int itemsPerPage = 100;
  String query;
  
  FeedProvier(){
    query = "";
  }
  
  FeedProvier.byGroup( String group ){
    query = "group=${group}";
  }
  
  FeedProvier.byFeed( Feed feed ){
    query = "feed=${feed.id}";
  }
  
  
  Future<List<FeedItemList>> getPage({ int page: 0 }){
    Completer<List<FeedItemList>> completer = new Completer();
    String href = "http://localhost:8080/feed?${query}&start=${page * itemsPerPage}";
    
    HttpRequest.getString(href).then((t){
      Map parsed = parse(t);
      
      List<FeedItemList> newFeeds = parsed["Items"].map((Map feedItem){
        DateTime time = new DateTime.fromMillisecondsSinceEpoch( feedItem["Updated"] * 1000 );
        Feed feed = reader.getFeedById(feedItem["FeedId"]);        
        
        return new FeedItemList( feedItem["Id"], feedItem["Title"], time, feedItem["Link"], feedItem["Author"], feed, feedItem["IsRead"] > 0 );
      } ).toList();
      
      completer.complete( newFeeds );
    });
   
    return completer.future;
  }
  
}

class FeedEntryListWidget extends ui.FlowPanel{
  FeedProvier provider;
  
  FeedEntryListWidget(){
  }
  
  void setFeedProdiver(FeedProvier provider){
    this.provider = provider;
    this.clear();
    this.provider.getPage(page: 0).then(addFeeds);
    
  }
  
  void addFeeds( List<FeedItemList> feedItems ){
    
    feedItems.map((feed){
      return new FeedEntryListWidgetEntry(feed);
    }).forEach(this.add);
    
  }
  
  void closeAll(){
    getChildren().forEach((ui.Widget widget){
      if( widget is FeedEntryListWidgetEntry ){
        (widget as FeedEntryListWidgetEntry).closeContent();
      }
    });
  }
  
}

class FeedEntryListWidgetEntry extends ui.FlowPanel{
  FeedItemList item;
  
  ui.Label titleLabel = new ui.Label();
  ui.Label timeLabel = new ui.Label();
  ui.Label summaryLabel = new ui.Label();
  
  ui.SimplePanel content = null;
  
  bool isOpen = false;
  Element title = new DivElement();
  
  FeedEntryListWidgetEntry(this.item){
    title.classes.add("entry-title");
    
    getElement().append(title);
    
    titleLabel.setStylePrimaryName("entry-feedTitle");
    summaryLabel.setStylePrimaryName("entry-summary");
    timeLabel.setStylePrimaryName("entry-time" ); 
    addWidget(titleLabel, title);
    addWidget(timeLabel, title);
    addWidget(summaryLabel, title);
    
    title.onClick.listen(this.toggleContent);
    
    update();
  }
  
  void update(){
    titleLabel.text = item.feed.title;
    summaryLabel.text = item.title;
    timeLabel.text = item.getFormattedTime();
    
    title.style.backgroundColor = item.isRead ? "#EEE" : "#FFF";
  }
  
  void toggleContent(event){
    isOpen = !isOpen;
    
    if(isOpen){
      if(content == null){
        content = new ui.SimplePanel(new ui.Label("Loading..."));
        updateContent();
      }
      
      getElement().scrollIntoView();
    }
    
    (getParent() as FeedEntryListWidget).closeAll();
    
    if(content != null){
      if(isOpen){
        add(content);
      } else {
        remove(content);
      }
    }
  }
  
  void closeContent(){
    if(content != null && content.getParent() != null ){
      remove(content);
    }
  }
  
  void updateContent(){
    item.getEntry().then((FeedEntryModel model){
      var widget = new FeedItemContentWidget(model);
      content.remove(content.getWidget());
      content.add(widget);
      
      getElement().scrollIntoView();
      item.markAsRead();
      update();
    });
  }
  
}

class FeedItemContentWidget extends ui.FlowPanel {
  FeedEntryModel entry;
  
  ui.Anchor title = new ui.Anchor();
  ui.Label author = new ui.Label();
  ui.HtmlPanel content = new ui.HtmlPanel("");
  
  FeedItemContentWidget(this.entry){
    setStylePrimaryName("feed-content");
    
    title.text = entry.title;
    author.text = entry.author;
    
    title.setStylePrimaryName("feed-content-title");
    title.target = "_blank";
    title.href = entry.link;
    
    content.setStylePrimaryName("feed-content-body");
    content.getElement().innerHtml =  entry.content;   
    
    content.getElement().queryAll("a").forEach((anchor){
      anchor.target = "_blank";
    });
    
    add(title);
    add(author);
    add(content);
  }
  
}