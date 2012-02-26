//© DevHost Ltd, 2006 v1.7

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

function FHToggleHiddenParagraphs(iParagraph, iImage, stHidden, stVisible)
{if (iParagraph.style.display=="none")
  {iParagraph.style.display="";
   iImage.src=stVisible;
  }
else 
  {iParagraph.style.display="none";
   iImage.src=stHidden;
  }
}

function extractFileName(stFullPath)
{
  var iLastSlash; // the position of the last slash in the path
  var stFileName;  // the name of the file
  iLastSlash = stFullPath.lastIndexOf("/");
  stFileName = stFullPath.substring(iLastSlash+1,stFullPath.length);
  return stFileName;
}

//This function is used to pass a contextstring, extracted from a file name, to a website url
function extractFileNameWithoutKnownExtension(stFullPath)
{
  var iLastSlash;// the position of the last slash in the path
  var stFileName, stExt;// the name of the file
  var boRemoveExtension=new Boolean();
  var stPage;
  var i;
  iLastSlash = stFullPath.lastIndexOf("/");
  stFileName = stFullPath.substring(iLastSlash+1,stFullPath.length);

  //find the extension
  i = stFileName.lastIndexOf(".");
  stExt = stFileName.substring(i,stFileName.length);
  stExt = stExt.toLowerCase();
  //is this a known extension that we want to remove
  boRemoveExtension = false;
  if (stExt == ".html")
    {boRemoveExtension = true;}
  if (stExt == ".htm")
    {boRemoveExtension = true;}
  if (stExt == ".asp")
    {boRemoveExtension = true;}
  if (stExt == ".php")
    {boRemoveExtension = true;}

  if (boRemoveExtension = true)
    {stFileName = stFileName.substring(0,i);}

  return stFileName;
}