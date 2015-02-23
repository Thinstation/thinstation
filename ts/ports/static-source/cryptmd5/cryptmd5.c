#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <crypt.h>


/* Program to generate MD5 based passwords for use in the ntestation
 * project. 
 *
 * Taken from 
 * http://sources.redhat.com/ml/bug-gnats/2002-02/msg00015.html
 * and from
 * http://www.gnu.org/manual/glibc-2.2.3/html_chapter/libc_32.html#SEC658
 *
 *   gcc cryptmd5.c -o cryptmd5 -lcrypt -static && strip crypt 
 *
 * to create the binary 'cryptmd5'. Results in a 410k binary. Linked
 * dynamically it's 5k (!) in size. The thinstation tree includes a crypt
 * library as well, so maybe it could be linked dynamically against
 * that.
 * 
 * Ben Chapman bchapman@utulsa.edu Wed Apr 23 12:59:27 CDT 2003
 *
 * WARNING: I am NOT a C programmer. I'm just stitching together other
 * people's code. Please double-check this for correctness.
 *
 */

int 
main (int argc, char **argv)
{
  unsigned long seed[2];
  char salt[] = "$1$........";
  const char *const seedchars = 
    "./0123456789ABCDEFGHIJKLMNOPQRST"
    "UVWXYZabcdefghijklmnopqrstuvwxyz";
  char *password;
  int i;

  if (argc != 2)
    {
      fprintf(stderr, "usage: %s password\n", argv[0]);
      exit(2);
    }
  
  /* Generate a (not very) random seed.  
     You should do it better than this... */
  seed[0] = time(NULL);
  seed[1] = getpid() ^ (seed[0] >> 14 & 0x30000);
  
  /* Turn it into printable characters from `seedchars'. */
  for (i = 0; i < 8; i++)
    salt[3+i] = seedchars[(seed[i/5] >> (i%5)*6) & 0x3f];
  
  /* Read in the user's password and encrypt it. */
  password = crypt(argv[1], salt);
  
  /* Print the results. */
  puts(password);
  return 0;
}
