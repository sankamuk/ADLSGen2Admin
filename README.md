# Azure ADLS Gen2 CLI Tool

A simple CLI tool to use Azure ADLS Gen2.

***Features:***
- Simple and lightweight BASH (Unix) and Powershell (Windows) based CLI utility
- Uses AAD SPN(OAuth) to authenticate request, 
- This Client Id, Client Secret and AAD Tenent Id should be available in environment as variable CLIENT_ID, CLIENT_SECRET and TENENT_ID
- For unix version only curl and python 2.7 are enough (default available)
- For Windows version Powershell should be enough
- Currently the support ls, mkdir, rmdir, rm, cat, put operation
- Currently put only supports text files
- You can only cat text files

***Usage:***
- Unix

```
./adlsgen2admin.sh -a ls -f w6pd3jhfgdhnkbcontainer/container@/tmp/test_folder 
```

- Windows

```
.\adlsgen2admin.ps1 /a ls /f w6pd3jhfgdhnkbcontainer/container@/tmp/test_folder 
```

