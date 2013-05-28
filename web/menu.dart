part of RabbitReader;

class Menu extends ui.FlowPanel{
  FeedTreeWidget feedTree = new FeedTreeWidget();  
  ui.Label home = new ui.Label("Home");
  ui.Label starred = new ui.Label("★ Starred");
  AddFeedButton addFeed = new AddFeedButton();
  
  Menu(){
    home.setStylePrimaryName("scroll-tree-home");
    starred.setStylePrimaryName("scroll-tree-starred");
    
    add(addFeed);
    add(home);
    add(starred);
    getElement().append(new HRElement());
    add(feedTree);
    
    home.getElement().onClick.listen(this.displayHome);
    starred.getElement().onClick.listen(this.displayStarred);
  }
  
  void displayHome(e){
    reader.setFeedProdiver(new FeedEntryProvier());
  }
  
  void displayStarred(e){
    reader.setFeedProdiver(new FeedEntryStarredProvier());
  }
  
  
}

class AddFeedButton extends ui.Button implements event.ClickHandler {
  
  AddFeedButton() : super ("ADD"){
    addClickHandler(this);
  }
  
  void onClick(event.ClickEvent event){
    FeedPopup popup = new FeedPopup();
    popup.show();
    popup.position( this, 100, 100 );    
  }
}

class FeedPopup extends ui.PopupPanel implements event.ClickHandler {
  
  ui.TextBox box = new ui.TextBox();
  ui.Button addButton = new ui.Button("ADD");
  ui.FlowPanel body = new ui.FlowPanel();
  
  FeedPopup() : super(true,true){
    getElement().style
      ..backgroundColor = "white"
      ..border = "1px solid black";
    
    add(body);
    
    body.add(new ui.Label("Enter feed url:"));
    body.add(box);
    body.add(addButton);
    
    addButton.addClickHandler(this);
  }
  
  void onClick(event.ClickEvent event){
    box.enabled = false;
    addButton.enabled = false;
    body.add(new ui.Label("Loading..."));
    
    String jsonData = stringify({"uri": box.getValue()});    
    HttpRequest request = new HttpRequest(); // create a new XHR
    request.open("POST", "/add");
    request.setRequestHeader("Content-Type", "application/json");
    request.send(jsonData);
    
    request.onLoad.listen((e) {
      // Note: file:// URIs have status of 0.
      if ((request.status >= 200 && request.status < 300) ||
          request.status == 0 || request.status == 304) {
        reader.updateFeeds(); 
      } else {
        window.alert( request.responseText );
      }
      this.hide(true);
    });

    request.onError.listen((e) {
      window.alert( e.toString() );
    });
    
  }
}

class TreeLabel extends ui.FlowPanel implements event.HasClickHandlers {
  
  ui.Label titleLabel = new ui.Label();
  ui.Label unreadLabel = new ui.Label("(0)");
  
  TreeLabel(){
    titleLabel.setStylePrimaryName("scroll-tree-item-title");
    unreadLabel.setStylePrimaryName("scroll-tree-item-unread");
    
    add(titleLabel);
    add(unreadLabel);
  }
  
  void set text(String val) {
    titleLabel.text = val;
  }
  
  void set unread(int val) {
    unreadLabel.visible = val > 0;
    unreadLabel.text = " (" + val.toString() + ")";
    
    titleLabel.getElement().style.fontWeight = val > 0 ? "bold" : "";
  }
  
  void set selected(bool val) {
    titleLabel.getElement().style.color = val ? "rgb(209, 72, 54)" : "";  
  }
  
  event.HandlerRegistration addClickHandler(event.ClickHandler handler) {
    return addDomHandler(handler, event.ClickEvent.TYPE);
  }
}

abstract class SortableTreeItem extends ui.TreeItem  {
  static TreeLabel lastSelectedLabel = null;
  
  static SortableTreeItem startDrag; 
  static Element lastDragged = null;
  
  TreeLabel label = new TreeLabel();
  
  SortableTreeItem(){
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
    if( parent is SortableTreeItem ){ parent.updateTitle(); }
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
    
    if( startDrag is TreeGroupWidget && parent is TreeGroupWidget ){
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
    if( lastSelectedLabel != null )
      lastSelectedLabel.selected = false;
    
    reader.setFeedProdiver(getProvider());
    label.selected = true;
    lastSelectedLabel = label;
  }
  
  FeedEntryProvier getProvider();
  int getUnreadItems();
  String getTitle();
  
}

class FeedLabelWidget extends SortableTreeItem implements event.ClickHandler  {
  Feed feed;
  StreamSubscription onUpdateSubscription;
  
  FeedLabelWidget(this.feed){
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
  
  FeedEntryProvier getProvider(){
    return new FeedEntryFeedProvier(feed);
  }
  
  int getUnreadItems(){
    return feed.unreadItems;
  }
  
  String getTitle(){
    return feed.title;
  }

}

class TreeGroupWidget extends SortableTreeItem implements event.ClickHandler {
  String group;
  
  TreeGroupWidget(this.group) {
  }
  
  FeedEntryProvier getProvider(){
    return new FeedEntryGroupProvier(group);
  }
  
  int getUnreadItems(){
    if( getChildren() == null )
      return 0;
    
    return this.getChildren().fold(0, (val, SortableTreeItem child){
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
    if(feed.active == false)
      return;
    
    FeedLabelWidget widget = new FeedLabelWidget(feed);
    
    String group = widget.feed.group;
    
    if(group == ""){
      addItem(widget);
      return;
    }
    
    if( groups.containsKey(group) ){
      groups[group].addItem(widget);
      return;
    }
    
    TreeGroupWidget leaf = new TreeGroupWidget(group);
    leaf.addItem(widget);
    addItem(leaf);
    
    groups[group] = leaf; 
  }
  
  void updateOrder(){
    Map<int,Map> orderMap = new Map();
    int currentPriority = 0;
    
    void addToMap( ui.TreeItem item ){
      if( item is FeedLabelWidget ){
        String group = "";
        
        if( item.getParentItem() is TreeGroupWidget )
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