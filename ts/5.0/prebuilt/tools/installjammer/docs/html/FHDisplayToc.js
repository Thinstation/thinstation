/*Copyright DevHost Ltd. 2007 : v2.026*/
var isIE = navigator.appName.toLowerCase().indexOf("explorer") > -1;
var mdi = (isIE) ? textSizes[1]:textSizes[3];
var sml = (isIE) ? textSizes[2]:textSizes[4];
var oldCurrentNumber = "", oldLastVisitNumber = "";
var toDisplay = new Array();
for (ir=0; ir<tocTab.length; ir++) 
  {toDisplay[ir] = tocTab[ir][0].split(".").length==1;}

function reDisplay(currentNumber,tocChange,noLink,e) {
  if (e)
  {
    ctrlKeyDown = (isIE) ? e.ctrlKey : (e.modifiers==2);
    if (tocChange && ctrlKeyDown) tocChange = 2;
  }
  try
  {toc.document.clear();}
  catch (e)
  {location.href = "index.html";}
  toc.document.write("<!-- saved from url=(0014)about:internet -->\n<html>\n<head>\n<title>ToC</title>\n</head>\n<body bgcolor=\"" + backColor + "\">\n<table border=0 cellspacing=1 cellpadding=0>\n<tr>\n<td colspan=" + (nCols+1) + "><a href=\"javaScript:history.go(0)\" onMouseDown=\"parent.reDisplay('" + tocTab[0][0] + "',0,0)\" style=\"font-family: " + fontTitle + "; font-weight:bold; font-size:" + textSizes[0] + "em; color: " + titleColor + "; text-decoration:none\">" + tocTab[0][1] + "</a></td></tr>\n<tr>");

  for (k=0; k<nCols; k++) 
    {toc.document.write("<td>&nbsp;</td>");}
  toc.document.write("<td width=240>&nbsp;</td></tr>");

  var currentNumArray = currentNumber.split(".");
  var currentLevel = currentNumArray.length-1;

  var currentIndex = null;
  for (i=0; i<tocTab.length; i++) 
  {
    if (tocTab[i][0] == currentNumber) 
      {currentIndex = i; break;}
  }

  if (currentIndex == null)
    {for (i=0; i<tocTab.length; i++) 
      {if (tocTab[i][3] == currentNumber) 
         {
           currentIndex = i;
           currentNumber = tocTab[i][0];
           currentNumArray = currentNumber.split(".");
           currentLevel = currentNumArray.length-1;
           break;
         }
       if (tocTab[i][4] == currentNumber) 
         {
           currentIndex = i;
           currentNumber = tocTab[i][0];
           currentNumArray = currentNumber.split(".");
           currentLevel = currentNumArray.length-1;
           break;
         }
      }
    }

  if (currentIndex == null)
    {currentIndex=0;}//the requested page was not found, so show the home page instead
        
  if (currentIndex < tocTab.length-1) 
    {
      nextLevel = tocTab[currentIndex+1][0].split(".").length-1;
      currentIsExpanded = nextLevel > currentLevel && toDisplay[currentIndex+1];
    } 
  else currentIsExpanded = false;

  theHref = (noLink) ? "" : tocTab[currentIndex][2];
  theTarget = tocTab[currentIndex][3];

  for (i=1; i<tocTab.length; i++) 
    {
      if (tocChange) 
        {
          thisNumber = tocTab[i][0];
          thisNumArray = thisNumber.split(".");
          thisLevel = thisNumArray.length-1;
          isOnPath = true;
          if (thisLevel > 0) 
            {
              for (j=0; j<thisLevel; j++) 
                {isOnPath = (j>currentLevel) ? false : isOnPath && (thisNumArray[j] == currentNumArray[j]);}
            } 
          toDisplay[i] = (tocChange == 1) ? isOnPath : (isOnPath || toDisplay[i]);
          if (thisNumber.indexOf(currentNumber+".")==0 && thisLevel > currentLevel) 
            {                 
              if (currentIsExpanded) toDisplay[i] = false;
              else toDisplay[i] = (thisLevel == currentLevel+1); 
            }
        } 
    } // End of loop over the tocTab


  var scrollY=0, addScroll=tocScroll; 
  for (i=1; i<tocTab.length; i++) 
    {
      if (toDisplay[i]) 
        {
          thisNumber = tocTab[i][0];
          thisNumArray = thisNumber.split(".");
          thisLevel = thisNumArray.length-1;
          isCurrent = (i == currentIndex);
          if (i < tocTab.length-1) 
            {
              nextLevel = tocTab[i+1][0].split(".").length-1;
              img = (thisLevel >= nextLevel) ? "topic.png" : ((toDisplay[i+1]) ? "open.png" : "closed.png");
            } 
          else img = "topic.png";

          if (addScroll) scrollY+=((thisLevel<2)?mdi:sml)*25;
          if (isCurrent) addScroll=false;
          if (noLink)
            thisTextColor = (thisNumber==oldCurrentNumber) ? currentColor:((thisNumber==oldLastVisitNumber) ? lastVisitColor:normalColor);
          else thisTextColor = (thisNumber==currentNumber) ? currentColor:((thisNumber==oldCurrentNumber) ? lastVisitColor:normalColor);

          toc.document.writeln("<tr valign=top>");

          for (k=1; k<=thisLevel; k++) 
            {toc.document.writeln("<td>&nbsp;</td>");}

          toc.document.writeln("<td valign=top><a href=\"javaScript:history.go(0)\" onMouseDown=\"parent.reDisplay('" + thisNumber + "'," + tocBehaviour[0] + "," + tocLinks[0] + ",event)\"><img src=\"Images/" + img + "\" border=0></a></td> <td colspan=" + (nCols-thisLevel) + ">&nbsp;<a href=\"javaScript:history.go(0)\" onMouseDown=\"parent.reDisplay('" + thisNumber + "'," + tocBehaviour[1] + "," + tocLinks[1] + ",event)\" style=\"font-family: " + fontLines + ";" + ((thisLevel<=mLevel)?"font-weight:bold":"") +  "; font-size:" + ((thisLevel<=mLevel)?mdi:sml) + "em; color: " + thisTextColor + "; text-decoration:none\">" + ((showNumbers)?(thisNumber+" "):"") + tocTab[i][1] + "</a></td></tr>");
        }
    }

  if (!noLink) 
    { 
      oldLastVisitNumber = oldCurrentNumber;
      oldCurrentNumber = currentNumber;
    }

  toc.document.writeln("</table>\n");
  toc.document.writeln("\n\r\n\r  <br>\n\r  <hr>\n\r <div style=\'font-family: Verdana; font-size:0.6em; color:#000000\'>\n\r  \n\r  </div>\n</body></html>");
  if (tocScroll) toc.scroll(0,scrollY);
  if (theHref) 
    if (theTarget=="top") top.location.href = theHref;
    else if (theTarget=="parent") parent.location.href = theHref;
    else if (theTarget=="blank") open(theHref,"");
    else content.location.href = theHref;
  toc.document.close();
}