part of RabbitReader;

class SortableTreeItemWidget extends ui.TreeItem  {
  
  static SortableTreeItemWidget startDrag; 
  static Element lastDragged = null;
  ui.Label label = new ui.Label("");
  
  SortableTreeItemWidget(){
    setWidget(label);
    label.setStylePrimaryName("scroll-tree-item");
    
    getElement().draggable = true;
    
    getElement().onDragStart.listen(this.dragStart);
    getElement().onDragEnd.listen(this.dragEnd);
    
    getElement().onDragOver.listen(this.dragOver);
    
    //getElement().onDragEnter.listen(this.dragEnter);
    getElement().onDragLeave.listen(this.dragLeave);
    
    getElement().onDrop.listen(this.onDrop);
    
    
  }
  
  void dragStart(MouseEvent event){
    getElement().style.opacity = "0.4";
    startDrag = this;
    
    event.stopPropagation();
  }
  
  void dragEnd(MouseEvent event){
    getElement().style.opacity = null;
  }
  
  void dragOver(MouseEvent event){
    Element elem = getDraggableParent(event);

    resetBorderStyle( elem );
    
    if( event.offset.y < elem.clientHeight / 2 ){
      elem.style.borderTop = "1px solid black";
    } else {
      elem.style.borderBottom = "1px solid black";
    }
    
    if( lastDragged != null && lastDragged != elem ){
      resetBorderStyle( lastDragged );
    }
    
    lastDragged = elem;
    
    event.preventDefault();
  }
  
  //void dragEnter(MouseEvent event){
    //Element elem = event.target;
    //elem.style.borderBottom = "1px solid black";
  //}
  
  void dragLeave(MouseEvent event){    
    Element elem = event.target;
    resetBorderStyle( lastDragged );
  }
  
  void onDrop(MouseEvent event){
    Element elem = getDraggableParent(event);
    resetBorderStyle( elem );
    resetBorderStyle( lastDragged );
    
    if( startDrag == this || startDrag == null )
      return;
    
    ui.TreeItem parent = this.getParentItem();
    
    if( startDrag is FeedTreeGroupWidget && parent is FeedTreeGroupWidget ){
      return;
    }
    
    startDrag.remove();
    
    if( event.offset.y < elem.clientHeight / 2 ){
      parent.insertItem(parent.getChildren().indexOf(this), startDrag);
    } else {
      parent.insertItem(parent.getChildren().indexOf(this) + 1, startDrag);
    }
    
    startDrag = null;
    getTree().updateOrder();
    event.stopPropagation();
  }
  
  Element getDraggableParent(MouseEvent event){
    Element elem = event.target;
    
    while(!elem.draggable) elem = elem.parent;
    
    return elem;    
  }
  
  void resetBorderStyle(Element elem){
    elem.style.borderTop = "";
    elem.style.borderBottom = "";
  }
  
}

class FeedTreeItemWidget extends SortableTreeItemWidget implements event.ClickHandler  {
  Feed feed;
  
  FeedTreeItemWidget(this.feed){
    label.text = feed.title;
    
    label.addClickHandler(this);
  }
  
  void onClick(event.ClickEvent event){
    reader.setFeedProdiver(new FeedProvier.byFeed(feed));
  }
}

class FeedTreeGroupWidget extends SortableTreeItemWidget implements event.ClickHandler {
  String group;
  
  FeedTreeGroupWidget(this.group) {
    label.text = group;
    
    label.addClickHandler(this);
  }
  
  void onClick(event.ClickEvent event){
    reader.setFeedProdiver(new FeedProvier.byGroup(group));
  }
}


class FeedTreeWidget extends ui.Tree {
  
  List<Feed> feeds;
  
  FeedTreeWidget(this.feeds){
    
    Map<String, ui.TreeItem> groups = new Map();
    
    List<FeedTreeItemWidget> items = feeds.map((Feed feed){
      return new FeedTreeItemWidget(feed);
    }).toList();
    
    items.forEach((FeedTreeItemWidget item){
      String group = item.feed.group;
      
      if(group == ""){
        addItem(item);
        return;
      }
      
      if( groups.containsKey(group) ){
        groups[group].addItem(item);
        return;
      }
      
      FeedTreeGroupWidget leaf = new FeedTreeGroupWidget(group);
      leaf.addItem(item);
      addItem(leaf);
      
      groups[group] = leaf; 
    });
    
  }
  
  void updateOrder(){
    Map<int,Map> orderMap = new Map();
    int currentPriority = 0;
    
    void addToMap( ui.TreeItem item ){
      if( item is FeedTreeItemWidget ){
        String group = "";
        
        if( item.getParentItem() is FeedTreeGroupWidget )
          group = item.getParentItem().group;
        
        orderMap[ item.feed.id.toString() ] = {'priority': currentPriority, 'group': group};
        currentPriority++;
      }
      
      if( item is ui.TreeItem && item.getChildren() != null )
        item.getChildren().forEach(addToMap);
    }
    
    root.getChildren().forEach(addToMap);
    
    String jsonData = stringify(orderMap);
    HttpRequest request = new HttpRequest(); // create a new XHR
    request.open("POST", "http://localhost:8080/updateOrder");
    request.setRequestHeader("Content-Type", "application/json");
    request.send(jsonData);
  }
  
}