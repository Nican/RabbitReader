part of RabbitReader;

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
  
  ui.HtmlPanel starLabel = new ui.HtmlPanel("&#9733;");
  ui.Label titleLabel = new ui.Label();
  ui.Label timeLabel = new ui.Label();
  ui.Label summaryLabel = new ui.Label();
  
  ui.SimplePanel content = null;
  
  bool isOpen = false;
  Element title = new DivElement();
  
  FeedEntryListWidgetEntry(this.item){
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
    item.getContent().then((String model){
      var widget = new FeedItemContentWidget(item);
      content.remove(content.getWidget());
      content.add(widget);
      
      getElement().scrollIntoView();
      item.markAsRead();
      update();
    });
  }
  
}

class FeedItemContentWidget extends ui.FlowPanel {
  FeedItemList entry;
  
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