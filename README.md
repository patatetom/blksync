# blksync
block device synchronisation

> _for a few years now, I've been getting into the habit of having my Linux on an external USB disk, which means I can carry my system in my pocket, use it whenever a "capable" PC is available, and access my files and favorite tools in my own carefully configured environment._
>
> _in addition to my ordinary backups (eg. `/home/`), I wanted to set up a second external USB backup disk (SSD#2 thereafter) that would enable me to restart quickly under the same conditions (system/configuration/tools/files) in the event of a problem with my main disk (SSD#1 thereafter)._

```text
 USB                            USB         
 DISK#1                         DISK#2     
┌───────────┐                  ┌───────────┐
│MBR/GPT    │                  │MBR/GPT    │
│───────────│ blocksync-fast   │───────────│
│ESP        ├─────────────────►│ESP        │
│           │                  │           │
│───────────│ blocksync-fast   │───────────│
│SYSTEM     ├─────────────────►│SYSTEM     │
│Linux live │                  │Linux live │
│           │                  │           │
│           │                  │           │
│           │                  │           │
│           │                  │           │
│───────────│                  │───────────│
│…          │                  │…          │
└─┌───────┐─┘                  └─┌───────┐─┘
  │ U   U │                      │ U   U │  
  └───────┘                      └───────┘
```

`blksync` is a `bash` script that uses `blocksync-fast` to synchronize two disks :

- the first disk - _the main disk SSD#1_ - is a disk containing a first boot partition (ESP) and a second system partition (Linux live).
- the second disk - _the backup disk SSD#2_ - is a disk containing the same two partitions (eg. same size).

unlike the size of the two synchronized partitions, the backup disk SSD#2 doesn't need to be the same size as the main disk SSD#1.


## see also

- [blocksync-fast](https://github.com/nethappen/blocksync-fast)
