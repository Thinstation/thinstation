/* Find how deeply inside an .RPM the real data is */
/* kept, and report the offset in bytes */

/* Wouldn't it be a lot more sane if we could just untar these things? */

#include <stdlib.h>

/* These offsets keep getting bigger, so we're going to just bite a 2MB */
/* chunk of RAM right away so that we have enough.  Yeah, horrible */
/* quick and dirty implementation, but hey -- it gets the job done. */

#define RPMBUFSIZ 2097152
const char magic[][3]={"\x1F\x8B\x08"/*gzip*/,"BZh"/*bzip2*/};

main()
{
        char *buff = malloc(RPMBUFSIZ),*eb,*p;
        for (p = buff, eb = buff + read(0,buff,RPMBUFSIZ); p < eb; p++)
                if ((*p == magic[0][0] && p[1] == magic[0][1] && p[2] == magic[0][2]) ||
                    (*p == magic[1][0] && p[1] == magic[1][1] && p[2] == magic[1][2]))
                        printf("%d\n",p - buff),
                        exit(0);
        exit(1);
}
