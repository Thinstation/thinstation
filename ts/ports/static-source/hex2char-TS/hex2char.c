/* 
  (c) steve at steve dash parker dot org
  Released under GPL version 2 (http://www.gnu.org/copyleft/gpl.html)
   This program is free software; you can redistribute it and/or modify
   it under the terms of Version 2 of the the GNU General Public License
   as published by the Free Software Foundation. Any later versions of
   the GPL will be evaluated as they are released, and this software may
   or may not be re-released under those terms also.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  See the included file COPYING for more details.
*/

#include <stdio.h>

void main(int argc, char ** argv)
{
  int i;
  char c;

  if(argv[1] == NULL )
  { 
  	printf ("No arguments\n");
  	return 1;
  	}
  	  
  for (i=0; i<strlen(argv[1]); i++)
  {
    c=argv[1][i];
    if (c=='%')
    {
        i++;
        if (argv[1][i] > 64)
          c=((argv[1][i]-55)*16);
        else
          if (argv[1][i] > 47)
            c=((argv[1][i]-48)*16);
            
        i++;
        if (argv[1][i] > 64)
          c+=(argv[1][i]-55);
        else
          if (argv[1][i] > 47)
            c+=(argv[1][i]-48);
    }
    else
    if (c=='+')
      c=' ';
  printf("%c", c);
  }
}
