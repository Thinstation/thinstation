//© DevHost Ltd, 2005 v1.6
var type = "IE";

IdentifyBrowser();
window.onload=resizeSplitWndw;
window.onresize=resizeSplitWndw;
window.onbeforeprint=set_to_print;
window.onafterprint=reset_form;
window.onerror = errorHandler;

function resizeSplitWndw()
{
  if (type=="MO") 
  {
    document.getElementById('FHScroll').style.top= document.getElementById('FHNonScroll').offsetHeight;
  }
  //-------------------------------------------------
  if (type=="NN") 
  { 
    document.layers.FHScroll.style.top=document.layers.FHNonScroll.offsetHeight;
  }
  if (type=="OP") 
  { 
    document.all.FHScroll.style.top=document.all.FHNonScroll.offsetHeight;
    document.all.FHNonScroll.style.width= document.body.offsetWidth;
  }
  //-------------------------------------------------
  if (type=="IE") 
  {
    var oNonScroll=document.all.item("FHNonscroll");
    var oScroll=document.all.item("FHScroll");
    if (oScroll ==null) return;
    if (oNonScroll != null)
    document.all.FHNonScroll.style.position= "absolute";
    document.all.FHScroll.style.position= "absolute";
    document.all.FHScroll.style.overflow= "auto";
    document.all.FHScroll.style.height= "100%";
    document.all.FHNonScroll.style.width= document.body.offsetWidth;
    document.all.FHScroll.style.width= document.body.offsetWidth-4;
    document.all.FHScroll.style.top= document.all.FHNonScroll.offsetHeight;
    if (document.body.offsetHeight > document.all.FHNonScroll.offsetHeight)
    document.all.FHScroll.style.height= document.body.offsetHeight - document.all.FHNonScroll.offsetHeight;
    else 
    document.all.FHScroll.style.height=0;
  }
}

function errorHandler() {
  //alert("Error Handled"); 
  //When printing pages that contain mixed elements of hidden paragraphs and links, printing will
  //mistakenly raise an exception when parsing the elements, so we suppress it here.
  return true;
}

function set_to_print()
{
  var i;
  document.all.FHScroll.style.overflow="visible";
  document.all.FHScroll.style.width="100%";
  if (window.FHScroll)document.all.FHScroll.style.height = "auto";
  for (i=0; i < document.all.length; i++)
  {
    if (document.all[i].tagName == "BODY") 
    {
      document.all[i].scroll = "auto";
    }
    if (document.all[i].tagName == "A") 
    {
      document.all[i].outerHTML = "<a href=''>" + document.all[i].innerHTML + "</a>";
    }
  }
}

function reset_form()
{
  document.location.reload();
}

function IdentifyBrowser() 
{
  if (navigator.userAgent.indexOf("Opera")!=-1 && document.getElementById) type="OP";//Opera
  else if (document.all) type="IE";													//Internet Explorer e.g. IE4 upwards
  else if (document.layers) type="NN";													//Netscape Communicator 4
  else if (!document.all && document.getElementById) type="MO";
        //Mozila e.g. Netscape 6 upwards
  else type = "IE";
}

function OpenFileRelativeToCHMFolder(stFileName)
{
  var X, Y, sl, a, ra, link;
  ra = /:/;
  a = location.href.search(ra);
  if (a == 2)
    X = 14;
  else
    X = 7;
  sl = "\\";
  Y = location.href.lastIndexOf(sl) + 1;
  link = 'file:///' + location.href.substring(X, Y) + stFileName;
  location.href = link;
}