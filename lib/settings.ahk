global HyperSettings := {"Keymap":{}
    , "TabHotString":{}
    , "UserWindow":{}
    , "ScriptDir":["lib", "script"]
    , "Includer":"lib\Includer.ahk"
    , "SettingIni":["HyperSettings.ini", "HyperWinSettings.ini"]
    , "Basic":{}}

#Include lib/BasicFunc.ahk



; main 


InitSettings()



; this must be put at last , because userscript may stuck
if not FileExist(HyperSettings.Includer)
{
    GenIncluder(HyperSettings.ScriptDir, HyperSettings.Includer)
    Reload
}
#Include *i lib/Includer.ahk

; end

; functions for init settings
InitSettings()
{
    ; main settings
    if FileExist("HyperSettings.ini")
    {
        ReadSettings()
    }
    else
    {
        Debug("HyperSettings.ini not found, using default")
        DefaultKeySettings()
        DefaultBasicSettings()
        DefaultHotStringSettings()
        SaveSettings()
    }

    ; for window
    if FileExist("HyperWinSettings.ini")
    {
        ReadWinSettings()
        ;for key, value in HyperSettings.UserWindow
        ;{
        ;    msgbox %key%
        ;}`
    }
    else
    {
        Debug("HyperWinSettings.ini not found, using default")
        DefaultWinSettings()
        SaveWinSettings()
    }
    LoadSettings()
}
LoadSettings()
{
    ; window load
    MapUserWindowKey()
    ; basic load
    Basic := HyperSettings.Basic
    ;; startup 
    if Basic.StartUp = 1
    {
        autostartLnk:=A_Startup . "\capsLock++.lnk"
        if FileExist(autostartLnk)
        {
            FileGetShortcut, %autostartLnk%, lnkTarget
            if(lnkTarget!=A_ScriptFullPath)
            {
                Debug("Create autostartLnk")
                FileCreateShortcut, %A_ScriptFullPath%, %autostartLnk%, %A_ScriptDir%
            }
                
        }
        else
        {
            Debug("Create autostartLnk")
            FileCreateShortcut, %A_ScriptFullPath%, %autostartLnk%, %A_ScriptDir%
        }
    }
    else
    {
        autostartLnk:=A_Startup . "\capsLock++.lnk"
        if FileExist(autostartLnk)
        {
            Debug("Delete autostartLnk")
            FileDelete, %autostartLnk%
        }
    }
    ;; admin
    if Basic.Admin = 1
    {
        if not A_IsAdmin ;running by administrator
        {
        Run *RunAs "%A_ScriptFullPath%" 
        ExitApp
        }   
    }
    ;; icon
    icon := Basic.Icon
    IfExist, %icon%
    {
        menu, TRAY, Icon,  %icon%, , 0
    }
    ;; settingmonitor
    if Basic.SettingMonitor = 1
    {
        SetTimer, SettingMonitor, 1000
    }
    else
    {
        SetTimer, SettingMonitor, off
    }
    ;; scriptmonitor
    if Basic.ScriptMonitor = 1
    {
        SetTimer, ScriptMonitor, 1000
    }
    else 
    {
        SetTimer, ScriptMonitor, off
    }
     



}
ScriptMonitor()
{
    static timestamps := {}
    static firsttime := 1

    lst := []
    for index, dir in HyperSettings.ScriptDir
    {
        lst.Push(FileList(dir)*)
    }
    lst.Push(A_ScriptName)
    ;msgbox %A_ScriptName%
    
    ; at first put all filename into timestamps
    if firsttime
    {
        for index, filename in lst
        {
            ;Msgbox %filename% record timestamp %temp%
            FileGetTime, temp, %filename%
            timestamps[filename] := temp
        }
        firsttime := 0
        return
    }

    ; first check if missing some file
    old_num := timestamps.count()
    new_num := lst.count()
    ;msgbox %old_num%, %new_num%
    if (old_num != new_num)
    {
        Msgbox Scripts number change, now reload
        GenIncluder(HyperSettings.ScriptDir, HyperSettings.Includer)
        Reload
    }

    ; main loop
    for index, filename in lst
    {
        FileGetTime, temp, %filename%
        if not timestamps.haskey(filename)
        {
            Msgbox New file %filename% detected, now reload 
            GenIncluder(HyperSettings.ScriptDir, HyperSettings.Includer) ; gen new includer.ahk
            Reload
        }
        else if timestamps[filename] != temp
        {
            ;old := timestamps[filename]
            ;msgbox %old% -> %temp%
            Msgbox %filename% changed, now reload
            GenIncluder(HyperSettings.ScriptDir, HyperSettings.Includer)
            Reload
        }
    }
}

GenIncluder(dirs, dst_file)
{
    ;msgbox includer works
    lst := []
    
    for index, dir in dirs
    {
        lst.Push(FileList(dir)*)
    }

    
    content := "; auto generated, don't touch me`n"
    for index, filename in lst
    {
        if (StrEq(filename,  dst_file))
        {
            ;ignore self
            Continue
        }
            
        line := Format("#Include {1}`n", filename)
        content .= line
    }
    ; msgbox write to %dst_file%
    FileRead, old_content, %dst_file%
    if not StrEq(old_content, content)
    {
        ;msgbox not eq
        ;msgbox old: %old_content% 
        Debug("write to " . dst_file)
        f := FileOpen(dst_file, "w")
        f.Write(content)
        f.Close()
    }
    
}

SettingMonitor()
{
    static timestamps := {}
    for index, filename in HyperSettings.SettingIni
    {
        FileGetTime, temp, %filename%
        if not timestamps.haskey(filename)
        {
            timestamps[filename] := temp
            Continue
        }
        else if (temp != timestamps[filename])
        {
            ;last := timestamps[filename]
            ;MsgBox %last%->%temp%
            MsgBox %filename% changed, read settings now
            timestamps[filename] := temp
            if (filename = "HyperSettings.ini")
            {
                ReadSettings()
            }
            if (filename = "HyperWinSettings.ini")
            {
                ReadWinSettings()
            }
            LoadSettings()
        }
    }
}

; functions for HyperSetting.ini
ReadSettings()
{
    IniRead, Keymap, HyperSettings.ini, Keymap
    Keymaps := StrSplit(Keymap, "`n")
    for index, line in Keymaps
    {
        pair := StrSplit(line, "=")
        keyname := pair[1]
        funcname := pair[2]
        AssignKeymap(keyname, funcname)
    }

    IniRead, TabHotString, HyperSettings.ini, TabHotString
    TabHotStrings := StrSplit(TabHotString, "`n")
    for index, line in TabHotStrings
    {
        pair := StrSplit(line, "=")
        str := pair[1]
        sub := pair[2]
        AssignHotString(str, sub)
    }

    IniRead, Basic, HyperSettings.ini, Basic
    Basics := StrSplit(Basic, "`n")
    for index, line in Basics
    {
        pair := StrSplit(line, "=")
        key := pair[1]
        val := pair[2]
        AssignBasic(key, val)
    }
}
SaveSettings()
{
    for key, val in HyperSettings.Keymap
    {
        IniWrite, % val, HyperSettings.ini, Keymap, % key
    }
    for key, val in HyperSettings.TabHotString
    {
        IniWrite, % val, HyperSettings.ini, TabHotString, % key
    }
    for key, val in HyperSettings.Basic
    {
        IniWrite, % val, HyperSettings.ini, Basic, % key
    }
}

AssignHotString(str, sub)
{
    old_val := HyperSettings.TabHotString[str]
    if (old_val && old_val != sub)
    {
        MsgBox Duplicate HotString: %str%`nold value: %old_val%`nnew value: %sub%
    }
    ;msgbox %str%, %sub%
    HyperSettings.TabHotString[str] := sub
}
AssignKeymap(key, func_name)
{
    old_val := HyperSettings.Keymap[key]
    if (old_val && old_val != func_name)
    {
        MsgBox Duplicate key: %key%`nold value: %old_val%`nnew value: %func_name%
    }
    ;msgbox %key%, %func_name%
    HyperSettings.Keymap[key] := func_name
}
AssignBasic(key, val)
{
    old_val := HyperSettings.Basic[key]
    if (old_val && old_val != val)
    {
        MsgBox Duplicate Basic: %key%`nold value: %old_val%`nnew value: %val%
    }
    ;msgbox %key%, %val%
    HyperSettings.Basic[key] := val
}
; functions for HyperWinSetting.ini

ReadWinSettings()
{
    IniRead, OutputVarSectionNames, HyperWinSettings.ini
    OutputVarSectionNames := StrSplit(OutputVarSectionNames, "`n")
    for index, appname in OutputVarSectionNames
    {
        IniRead, typ, HyperWinSettings.ini, %appname%, typ
        IniRead, key, HyperWinSettings.ini, %appname%, key
        IniRead, exe, HyperWinSettings.ini, %appname%, exe
        IniRead, id, HyperWinSettings.ini, %appname%, id
        ;msgbox %appname%, %typ%, %key%, %exe%, %id%
        HyperSettings.UserWindow[appname] := {"typ":typ
            ,"key":key
            ,"exe":exe
            ,"id":id}
    }
}
SaveWinSettings()
{
    for name, content in HyperSettings.UserWindow
    {
        for key, val in content
        {
            IniWrite, % val, HyperWinSettings.ini, %name%, % key
        }
    }
}
MapUserWindowKey()
{
    for appname, value in HyperSettings.UserWindow
    {
        key := "hyper_" . value["key"]
        func_name := Format("Window{1}(""{2}"",""{3}"")", value["typ"], value["id"], value["exe"])
        ; msgbox %key%, %funcname%
        AssignKeymap(key, func_name)
    }
    ;test := HyperSettings.Keymap["hyper_a"]
    ;msgbox %test%
}




; default setting
DefaultWinSettings()
{
    HyperSettings.UserWindow := {"Chrome":{"key":"a"
                                ,"typ":"B"
                                ,"id":"ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe"
                                ,"exe":"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"}

                            , "NotePad":{"key":"w"
                                ,"typ":"A"
                                ,"id":"ahk_class Notepad++"
                                ,"exe":"C:\Program Files\Notepad++\notepad++"}
                                
                            , "Qdir":{"key":"e"
                                ,"typ":"A"
                                ,"id":"ahk_class ATL:0000000140163FE0"
                                ,"exe":"D:\Tools\Q-Dir\Q-Dir_x64.exe"}

                            , "Msys2":{"key":"r"
                                ,"typ":"A"
                                ,"id":"ahk_class mintty"
                                ,"exe":"D:\Tools\msys2\msys2.exe"}

                            , "YoudaoNote":{"key":"q"
                                ,"typ":"A"
                                ,"id":"ahk_class NeteaseYoudaoYNoteMainWnd"
                                ,"exe":"C:\Program Files (x86)\Youdao\YoudaoNote\YoudaoNote.exe"}}
}
DefaultKeySettings()
{
    HyperSettings.Keymap.hyper_wheelup := "VolumeUp"
    HyperSettings.Keymap.hyper_wheeldown := "VolumeDown"

    HyperSettings.Keymap.hyper_up := "VolumeUp"
    HyperSettings.Keymap.hyper_down := "VolumeDown"
    HyperSettings.Keymap.hyper_left := "PrevDesktop"
    HyperSettings.Keymap.hyper_right := "NextDesktop"

    HyperSettings.Keymap.hyper_c := "UnixCopy"
    HyperSettings.Keymap.hyper_v := "UnixPaste"

    HyperSettings.Keymap.hyper_h := "MoveLeft"
    HyperSettings.Keymap.hyper_j := "MoveDown"
    HyperSettings.Keymap.hyper_k := "MoveUp"
    HyperSettings.Keymap.hyper_l := "MoveRight"

    HyperSettings.Keymap.hyper_i := "MoveHome"
    HyperSettings.Keymap.hyper_o := "MoveEnd"
    HyperSettings.Keymap.hyper_u := "PageUp"
    HyperSettings.Keymap.hyper_p := "PageDown"

    ;HyperSettings.Keymap.hyper_esc := "SuspendScript" ;changed to alt+esc
    HyperSettings.Keymap.hyper_backquote := "ToggleCapsLock"

    HyperSettings.Keymap.hyper_space := "WindowToggleOnTop"
    HyperSettings.Keymap.hyper_g := "WindowKill"

    HyperSettings.Keymap.hyper_1 := "WindowC(1)"
    HyperSettings.Keymap.hyper_2 := "WindowC(2)"
    HyperSettings.Keymap.hyper_3 := "WindowC(3)"
    HyperSettings.Keymap.hyper_4 := "WindowC(4)"
    HyperSettings.Keymap.hyper_5 := "WindowC(5)"
    HyperSettings.Keymap.hyper_minus := "WindowCClear"

    HyperSettings.Keymap.hyper_tab := "HyperTab"

    HyperSettings.Keymap.hyper_alt_1 := "switchDesktopByNumber(1)"
    HyperSettings.Keymap.hyper_alt_2 := "switchDesktopByNumber(2)"
    HyperSettings.Keymap.hyper_alt_3 := "switchDesktopByNumber(3)"

    HyperSettings.Keymap.hyper_s := "AppWox"
    HyperSettings.Keymap.hyper_t := "GoogleTransSel"
}
DefaultBasicSettings()
{
    HyperSettings.Basic.StartUp := 1
    HyperSettings.Basic.Debug := 0
    HyperSettings.Basic.Admin := 0
    HyperSettings.Basic.Icon := "hyper.ico"
    HyperSettings.Basic.SettingMonitor := 1
    HyperSettings.Basic.ScriptMonitor := 1
}
DefaultHotStringSettings()
{
    HyperSettings.TabHotString["sample"] := "this is a TabHotString sample"
    HyperSettings.TabHotString["date1"] := "<GetDateTime>"
    HyperSettings.TabHotString["date2"] := "<GetDateTime(""yyyy-M-d"")>"
    HyperSettings.TabHotString["cmain"] := "int main(int *argc, char **argv)"
}

Debug(msg)
{
    if HyperSettings.Basic.Debug = 1
    {
        Msgbox %msg%
    }
}