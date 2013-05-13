part of RabbitReader;

class FeedEntryListWidget extends ui.FlowPanel{
  FeedEntryProvier provider;
  
  int currentPage = 0;
  bool isLoading = false;
  bool hasMore = true;
  
  FeedEntryListWidget(){
    setStylePrimaryName("entry-list");
    
    getElement().onScroll.listen(this.onScroll);
  }
  
  void setFeedProdiver(FeedEntryProvier provider){
    this.provider = provider;
    this.hasMore = true;
    this.clear();
    currentPage = 0;
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
    
    feedItems.map((feed){
      return new FeedEntryListItemWidget(feed);
    }).forEach(this.add);
    
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
  ui.HtmlPanel content = new ui.HtmlPanel("");
  
  FeedEntryContentWidget(this.entry){
    setStylePrimaryName("feed-content");
    Uri sourceUri = Uri.parse(entry.feed.link);
    
    title.text = entry.title;
    author.text = entry.author;
    
    title.setStylePrimaryName("feed-content-title");
    title.target = "_blank";
    title.href = entry.link;
    
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
    
    add(title);
    add(author);
    add(content);
  }
  
}