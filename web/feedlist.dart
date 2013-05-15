part of RabbitReader;

class FeedList extends ui.DockLayoutPanel {
  
  Title title = new Title();
  FeedEntryListWidget entries = new FeedEntryListWidget();
  
  FeedList() : super(util.Unit.PX) {
    addNorth(title, 28.0);
    add(entries);
    
    getElement().style.position = "absolute";
    getElement().style.top = "0px";
    getElement().style.bottom = "0px";
    getElement().style.right = "0px";
    getElement().style.left = "0px";
    
    title.onRefresh.listen(this.onRefresh);
    title.onMarkRead.listen(this.onMarkRead);
  }
  
  void setFeedProdiver(FeedEntryProvier provider){
    entries.setFeedProdiver(provider);
  }
  
  void reloadList(){
    entries.reset();
    entries.loadPage();
  }
  
  void onRefresh(MouseEvent e){
    this.reloadList();
  }
  
  void onMarkRead(MouseEvent e){
    entries.provider.markRead().then((bool val){
    
      entries.getEntries().forEach((FeedEntryListItemWidget e){
        e.item.markAsRead();
        e.update();
      });
      
    }, onError: (err){
      window.alert(err);
    });
  }
  
  
  
}

class Title extends ui.FlowPanel {
  
  ui.Button refresh = new ui.Button("Refresh");
  ui.Button markRead = new ui.Button("Mark all as read");
  
  Title(){
    add(refresh);
    add(markRead);
  }
  
  Stream<MouseEvent> get onRefresh => refresh.getElement().onClick;
  Stream<MouseEvent> get onMarkRead => markRead.getElement().onClick;
  
}

class FeedEntryListWidget extends ui.FlowPanel{
  FeedEntryProvier provider;
  
  int currentPage = 0;
  bool isLoading = false;
  bool hasMore = true;
  
  FeedEntryListWidget(){
    setStylePrimaryName("entry-list");
    
    getElement().onScroll.listen(this.onScroll);
  }
  
  void reset(){
    this.hasMore = true;
    this.clear();
    currentPage = 0;
  }
  
  void setFeedProdiver(FeedEntryProvier provider){
    reset();
    this.provider = provider;
    loadPage();
  }
  
  void loadPage(){
    if(!this.hasMore || this.isLoading)
      return;
    
    this.provider.getPage(page: currentPage).then(addFeeds);
    currentPage++;
    this.isLoading = true;
  }
  
  void addFeeds( List<FeedEntry> feedItems ){
    this.isLoading = false;
    if( feedItems.length == 0 )
      this.hasMore = false;
    
    feedItems.forEach((FeedEntry feed){
      if(getWidgetByEntryId(feed.id) != null )
        return;
      
      var widget = new FeedEntryListItemWidget(feed);
      this.add(widget);
    } );
    
  }
  
  void closeAll(){
    getChildren().forEach((ui.Widget widget){
      if( widget is FeedEntryListItemWidget ){
        (widget as FeedEntryListItemWidget).closeContent();
      }
    });
  }
  
  void onScroll(Event event){
    if( getElement().scrollHeight - getElement().offsetHeight - getElement().scrollTop < 500 ){
      loadPage();      
    }
  }
  
  List<FeedEntryListItemWidget> getEntries(){
    List<FeedEntryListItemWidget> feeds = new List();
    
    for( ui.Widget widget in this.getChildren() ){     
      if( widget is FeedEntryListItemWidget )
        feeds.add(widget);
    }
    
    return feeds;
  }
  
  FeedEntryListItemWidget getWidgetByEntryId(int id){
    for( FeedEntryListItemWidget widget in this.getEntries() ){      
      if(widget.item.id == id)
        return widget;
    }
    return null;
  }
}

class FeedEntryListItemWidget extends ui.FlowPanel{
  FeedEntry item;
  
  ui.Label starLabel = new ui.Label("");
  ui.Label titleLabel = new ui.Label();
  ui.Label timeLabel = new ui.Label();
  ui.Label summaryLabel = new ui.Label();
  
  ui.SimplePanel content = null;
  
  bool isOpen = false;
  Element title = new DivElement();
  
  FeedEntryListItemWidget(this.item){
    title.classes.add("entry-title");
    
    getElement().append(title);
    
    starLabel.setStylePrimaryName("entry-star");
    titleLabel.setStylePrimaryName("entry-feedTitle");
    summaryLabel.setStylePrimaryName("entry-summary");
    timeLabel.setStylePrimaryName("entry-time" ); 
    
    addWidget(starLabel, title);
    addWidget(titleLabel, title);
    addWidget(timeLabel, title);
    addWidget(summaryLabel, title);
    
    title.onClick.listen(this.toggleContent);
    starLabel.getElement().onClick.listen(this.toggleStar);
    
    update();
  }
  
  void update(){
    titleLabel.text = item.feed.title;
    summaryLabel.text = item.title;
    timeLabel.text = item.getFormattedTime();
    
    title.style.backgroundColor = item.isRead ? "#EEE" : "#FFF";
    
    starLabel.getElement().innerHtml = item.labels.contains("star") ? "&#9733;" : "&#9734;";
  }
  
  void toggleStar(MouseEvent event){
    event.stopPropagation();
    
    if( item.labels.contains("star") ){
      item.labels.remove("star");
    } else {
      item.labels.add("star");
    }
    
    this.update();
    item.updateLabels();
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
    item.getContent().then((String model){
      var widget = new FeedEntryContentWidget(item);
      content.remove(content.getWidget());
      content.add(widget);
      
      getElement().scrollIntoView();
      item.markAsRead();
      update();
    });
  }
  
}

class FeedEntryContentWidget extends ui.FlowPanel {
  FeedEntry entry;
  
  ui.Anchor title = new ui.Anchor();
  ui.Label author = new ui.Label();
  //ui.HtmlPanel content = new ui.HtmlPanel("");
  IFrameElement content2 = new IFrameElement();
  
  FeedEntryContentWidget(this.entry){
    setStylePrimaryName("feed-content");
    Uri sourceUri = Uri.parse(entry.feed.link);
    
    title.text = entry.title;
    author.text = entry.author;
    
    title.setStylePrimaryName("feed-content-title");
    title.target = "_blank";
    title.href = entry.link;
    
    content2.sandbox = "";
    content2.seamless = true;
    content2.srcdoc = entry.content;
    //content2.contentWindow.document.body.innerHtml = entry.content;
    
    /*
    content.setStylePrimaryName("feed-content-body");
    content.getElement().innerHtml =  entry.content; 
    content.getElement().queryAll("img").forEach((ImageElement elem){
      Uri uri = Uri.parse(elem.src);
      
      //You can thank Original Life for this one. (http://jaynaylor.com/originallife/)
      //They do not specify their hostname in the path. We replace it here for their domain.
      if( uri.domain == window.location.hostname)
         elem.src = "${sourceUri.origin}/${uri.path}?${uri.query}"; 
      
    });
    
    content.getElement().queryAll("a").forEach((anchor){
      anchor.target = "_blank";
    });
    */
    
    add(title);
    add(author);
    //add(content);
    getElement().append(content2);
  }
  
  void onLoad(){
  }
}