# blksync
Block device synchronisation

```text
 USB                            USB         
 DISK #1                        DISK #2     
┌───────────┐                  ┌───────────┐
│MBR/GPT    │                  │MBR/GPT    │
│───────────│ blocksync-fast   │───────────│
│ESP        ├─────────────────►│ESP        │
│           │                  │           │
│───────────│ blocksync-fast   │───────────│
│SYSTEM     ├─────────────────►│SYSTEM     │
│           │                  │           │
│           │                  │           │
│           │                  │           │
│           │                  │           │
│           │                  │           │
│───────────│                  │───────────│
│OTHER/SPACE│                  │OTHER/SPACE│
└─┌───────┐─┘                  └─┌───────┐─┘
  │ U   U │                      │ U   U │  
  └───────┘                      └───────┘
```


## see also

- [blocksync-fast](https://github.com/nethappen/blocksync-fast)
