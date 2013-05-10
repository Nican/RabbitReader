part of RabbitReader;

class TreeLabel extends ui.FlowPanel implements event.HasClickHandlers {
  
  ui.Label titleLabel = new ui.Label();
  ui.Label unreadLabel = new ui.Label();
  
  TreeLabel(){
    titleLabel.setStylePrimaryName("scroll-tree-item-title");
    unreadLabel.setStylePrimaryName("scroll-tree-item-unread");
    
    unreadLabel.text = "(3)";
    
    add(titleLabel);
    add(unreadLabel);
  }
  
  void set text(String val) {
    titleLabel.text = val;
  }
  
  void set unread(int val) {
    unreadLabel.visible = val > 0;
    unreadLabel.text = "(" + val.toString() + ")";
  }
  
  event.HandlerRegistration addClickHandler(event.ClickHandler handler) {
    return addDomHandler(handler, event.ClickEvent.TYPE);
  }
}

abstract class SortableTreeItemWidget extends ui.TreeItem  {
  
  static SortableTreeItemWidget startDrag; 
  static Element lastDragged = null;
  
  TreeLabel label = new TreeLabel();
  
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
    
    label.addClickHandler(this);
    updateTitle();
  }
  
  void updateTitle(){
    label.text = getTitle(); 
    label.unread = getUnreadItems();
    
    ui.TreeItem parent = this.getParentItem();
    if( parent is SortableTreeItemWidget ){ parent.updateTitle(); }
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
  
  void onClick(event.ClickEvent event){
    reader.setFeedProdiver(getProvider());
  }
  
  FeedProvier getProvider();
  int getUnreadItems();
  String getTitle();
  
}

class FeedTreeItemWidget extends SortableTreeItemWidget implements event.ClickHandler  {
  Feed feed;
  StreamSubscription onUpdateSubscription;
  
  FeedTreeItemWidget(this.feed){
    feed.onUpdate.listen((Feed feed){ this.updateTitle(); });
  }
  
  /*
  void onLoad(){
    onUpdateSubscription = feed.onUpdate.listen(this.updateTitle);
    print("Listening to feed updates");
  }
  
  void onUnload(){
    onUpdateSubscription.cancel();
    print("Cancel feed updates");
  }
  */
  
  FeedProvier getProvider(){
    return new FeedProvier.byFeed(feed);
  }
  
  int getUnreadItems(){
    return feed.unreadItems;
  }
  
  String getTitle(){
    return feed.title;
  }

}

class FeedTreeGroupWidget extends SortableTreeItemWidget implements event.ClickHandler {
  String group;
  
  FeedTreeGroupWidget(this.group) {
  }
  
  FeedProvier getProvider(){
    return new FeedProvier.byGroup(group);
  }
  
  int getUnreadItems(){
    if( getChildren() == null )
      return 0;
    
    return this.getChildren().fold(0, (val, SortableTreeItemWidget child){
      return val + child.getUnreadItems();
    });
  }
  
  void addItem(ui.TreeItem item) {
    super.addItem(item);
    updateTitle();
  }
  
  String getTitle(){
    return group;
  }
}


class FeedTreeWidget extends ui.Tree {
  
  Map<String, ui.TreeItem> groups = new Map();
  
  FeedTreeWidget(){
    reader.onFeedAdded.listen(this.onFeedAdded);
  }
  
  void onFeedAdded(Feed feed){
    FeedTreeItemWidget widget = new FeedTreeItemWidget(feed);
    
    String group = widget.feed.group;
    
    if(group == ""){
      addItem(widget);
      return;
    }
    
    if( groups.containsKey(group) ){
      groups[group].addItem(widget);
      return;
    }
    
    FeedTreeGroupWidget leaf = new FeedTreeGroupWidget(group);
    leaf.addItem(widget);
    addItem(leaf);
    
    groups[group] = leaf; 
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