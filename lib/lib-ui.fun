
########################################
# lib-ui
########################################
#   built-in (7)
########################################
#     var ui = 'ui'.getlib();
##### UI ###############################
#     ui.form(caption, width, height, onclose, onmsg)
#     ui.run()
#     ui.delay(ms, doevent = false)
##### FORM #############################
#     form.show(alpha = 255, ontop = false)
#     form.hwnd() # Handle of Window
#     form.html() # DOM for HTML
########################################
# 1. form.show(alpha = 255, ontop = false)
#      alpha :
#        < 0 : Close
#        = 0 : Hide
#        > 0 : 1-255 : Show
#              1-254 : AlphaBlend
#              > 255 : Get Showing or not
#      ontop : Stay on top
########################################
use 'lib-os.fun';

var user32   = 'user32';
var IsIconic = user32.getapi('IsIconic', 'i:i');
var GetWindowRect = user32.getapi('GetWindowRect', 'is:i');
var MoveWindow    = user32.getapi('MoveWindow', 'iiiiii:i');
var HWND_BROADCAST = 0xffff;

//==============================================================
// UI Lib
//==============================================================
var ui = 'ui'.getlib();

//==============================================================
// Form
//==============================================================
class Form(caption, width, height, onclose, onmsg)
  if width = 0 then
    width  = 640;
    height = 480;
  end if;

  var f = ui.form(CalcCaption(caption), width, height, onclose, onmsg);
  var h;

  //------------------------------------
  // Public
  //------------------------------------
  var Web;
  var Doc;
  var Win;

  var AutoEvent = false;
  var Events    = new [];

  fun Show(alpha, ontop)
    f.show(alpha or 255, ontop);
    h   = f.hwnd();
    this.OnShowing();

    Web = f.html();
          Web.Navigate('about:blank');
          Web.Silent = true;
          Web.RegisterAsBrowser = false;
          Web.RegisterAsDropTarget = false;
    Doc = Web.Document;
          Doc.write(this.Html());
    Win = Doc.parentWindow;
          Doc.focus();
          InitFunHost();

    this.InitEvents();
    fireEvent('beforeShow', GetEvent());
    Focus();
    this.OnShow();
  end fun;

  fun ShowModal()
    if h = null then
      Show();
    end if;
    while not Closed() do
      Delay(1, true);
    end do;
  end fun;

  fun Closed()
    return not f.show(256);
  end fun;

  fun Hide()
    f.show(0);
  end fun;

  fun Close()
    f.show(-1);
  end fun;

  fun TopMost()
    f.show(256, true);
  end fun;

  fun SetCaption(cap)
    caption = cap.toStr();
    user32.getApi('SetWindowText', 'is:i').call(h, CalcCaption(caption));
  end fun;

  fun ShowMax(handle)
    return ShowWindow(handle or h, 3);  // MAXIMIZE
  end fun;

  fun ShowMin(handle)
    return ShowWindow(handle or h, 2);  // MINIMIZE
  end fun;

  fun Minimized(handle)
    return IsIconic(handle or h);
  end fun;

  fun ShowWindow(handle, state)
    return user32.getapi('ShowWindow', 'ii:i').call(handle or h, state or 1);
  end fun;

  fun Foreground(handle)
    return user32.getapi('SetForegroundWindow', 'i:i').call(handle or h);
  end fun;

  fun Active(handle)
    return user32.getapi('SetActiveWindow', 'i:i').call(handle or h);
  end fun;

  fun Focus(handle)
    return user32.getapi('SetFocus', 'i:i').call(handle or h);
  end fun;

  fun Flash(handle, state)
    return user32.getapi('FlashWindow', 'ii:i').call(handle or h, state);
  end fun;

  fun Timer(fn, ms, no, handle)
    return user32.getapi('SetTimer', 'iiii:i').call(handle or h, 0x400 + no, ms, fn);
  end fun;

  fun GetSize(handle)
    var s = 0.toChar().x(16);
    GetWindowRect(handle or h, s);
    result = new [
      x: str2int(s),
      y: str2int(s.substr(4))
    ];
    result.w = str2int(s.substr( 8)) - result.x;
    result.h = str2int(s.substr(12)) - result.y;
  end fun;

  fun Move(handle, x, y, width, height)
    MoveWindow(handle or h, x, y, width, height, true);
  end fun;

  fun HideBorder(handle)
    SetOptions(handle, -16, 0x70b0000); // 0x70f0000, 0x70b0000
    SetOptions(handle, -20, 0x10000);
    SetClasses(handle, -26, GetClasses(handle, -26) bit or 0x20000);
  end fun;

  // GWL_STYLE = -16; GWL_EXSTYLE = -20; GCL_STYLE = -26; CS_DROPSHADOW = $20000; WS_MAXIMIZEBOX = $10000;
  fun GetOptions(handle, option)
    result = user32.getapi('GetWindowLong', 'ii:i').call(handle or h, option);
  end fun;

  fun SetOptions(handle, option, value);
    result = user32.getapi('SetWindowLong', 'iii:i').call(handle or h, option, value);
  end fun;

  fun GetClasses(handle, option)
    result = user32.getapi('GetClassLong', 'ii:i').call(handle or h, option);
  end fun;

  fun SetClasses(handle, option, value);
    result = user32.getapi('SetClassLong', 'iii:i').call(handle or h, option, value);
  end fun;

  // WM_NCLBUTTONDOWN A1, HTCAPTION 2
  var HitTest = (lParam, wParam, handle) -> PostMsg(handle or h, 0xA1, wParam or 2, lParam);
  fun PostMsg(handle, msg, wParam, lParam)
    result = PostMessage(handle or h, msg, wParam, lParam);
  end fun;

  fun AcceptDrag()
    'shell32'.getapi('DragAcceptFiles', 'ii:v').call(h, 1); // Dragable
  end fun;

  fun GetDragFile(msg) // A file
    result = 0.toChar().x(1024);
    'shell32'.getapi('DragQueryFile', 'iipi:i').call(msg.wParam, 0, result, 1024);
    'shell32'.getapi('DragFinish', 'i:v').call(msg.wParam);
    result = result.replace(/\x00++$/, '');
  end fun;

  fun GetDragFiles(msg) // All files
    result = new [];
    var fs = 'shell32'.getapi('DragQueryFile', 'iipi:i').call(msg.wParam, 0xFFFFFFFF, nil, 0);
    for i = 0 to fs - 1 do
      var f = 0.toChar().x(1024);
      'shell32'.getapi('DragQueryFile', 'iipi:i').call(msg.wParam, i, f, 1024);
      f = f.replace(/\x00++$/, '');
      result.@add(f);
    end do;
    'shell32'.getapi('DragFinish', 'i:v').call(msg.wParam);
  end fun;

  fun Find(cap, claz)
    if claz = nil then
      claz = 'obj_Form';
    end if;
    result = FindWindow(claz, cap);
  end fun;

  //------------------------------------
  // Protected
  //------------------------------------
  fun Html()
    result = '<html><head>%s</head><body>%s</body></html>'.format(
        this.Head(), this.Body()
      );
  end fun;

  fun Head()
    result = '
<meta http-equiv="MSThemeCompatible" content="yes" />
<style>
 body{border:0; margin:0; overflow:visible}
 %s
</style>
'.format(this.Style()) & this.HeadEx();
  end fun;

  fun HeadEx()
  end fun;

  fun Style()
  end fun;

  fun Body()
  end fun;

  fun OnShowing()
  end fun;

  fun OnShow()
  end fun;

  fun OnClick(e)
  end fun;

  fun GetEvent(e)
    if e = null then
      e = Win.event;
    end if;
    return e;
  end fun;

  fun InitEvents()
    try
      Doc.onclick       = DoClick.@toEvent (this);
      Doc.oncontextmenu = DoFilter.@toEvent(this);
      Doc.onselectstart = DoFilter.@toEvent(this);
    except
      ?. @;
    end try;
  end fun;

  fun JsCall(js)
    Win.execScript(js, 'javascript');
  end fun;

  //------------------------------------
  // Private
  //------------------------------------
  fun DoClick(e)
    result = nil;
    try
      e = GetEvent(e);
      if AutoEvent and e.srcElement <> nil then
        var f = e.srcElement.getAttribute('fun:click', 2);
        if f <> null then
          f = this[f];
          if f <> null then
            fireEvent('beforeClick', e);
            try
              f(e);
            finally
              fireEvent('afterClick', e);
            end try;
          end if;
        else
          this.OnClick(e);
        end if;
      end if;
    except
      ?. 'fun:click: $@ at $@@()'.eval();
    end try;
  end fun;

  fun DoFilter(e) //BUG: Incorrect function
    result = nil;
    try
      e = GetEvent(e);
      var ee = e.srcElement;
      e.returnValue = false;
      while ee <> nil and ee.tagName <> 'body' do
        if ee.isTextEdit or ee.isContentEditable or ee.selectable = 'true' then
          e.returnValue = true;
          exit;
        end if;
        ee = ee.parentElement;
      end do;
    except
    end try;
  end fun;

  fun CalcCaption(c)
    result = c; //return;
    if 0x1234.toChar().toByte() > 0xff then
      result &= ' '.x(c.length());
    end if;
  end fun;

  fun Alert(c)
    Win.alert(c);
  end fun;

  //------------------------------------
  // js -> fun
  //------------------------------------
  fun InitFunHost()
    Web.PutProperty('Fun:Host', FunCall.@toEvent(this));
    Doc.write(`<script>window.Fun=window.external;</script>`);
  end fun;

  fun FunCall(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    try
      var f = this[a0];
      if f <> nil then
        return f(a1, a2, a3, a4, a5, a6, a7, a8, a9);
      end if;
    except
      ?. 'FunCall: $@ at $@@()'.eval();
    end try;
  end fun;

  fun FunCallUnsafe(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    var f = this[a0];
    if f <> nil then
      return f(a1, a2, a3, a4, a5, a6, a7, a8, a9);
    end if;
  end fun;

  //------------------------------------
  // Events
  //------------------------------------
  fun fireEvent(action, event)
    var e = nil;
    try e = Events[action]; except end try;
    if e <> nil then
      try
        e(event, this);
      except
        ?. action & ': ' & @;
      end try;
    end if;
  end fun;
end class;

//==============================================================
// Global functions
//==============================================================
fun Run()
  try
    ui.run();
  except
    ?. @;
  end try;
end fun;

fun Delay(ms, doevent)
  ui.delay(ms, doevent);
end fun;
