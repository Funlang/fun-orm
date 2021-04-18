
########################################
# lib-stream
########################################
#  Copyright (c) 2014, funlang.org
########################################

class Stream(fn, sz, cp)
  if fn <> nil then
    fn.move();
  end if;
  var first = true;

  if sz = nil then
    sz = 16 * 1024; // 16K 分批保存性能最好 (经验值, SSD 硬盘)
  end if;
  var ss  = 0.x(sz);
  var ptr = ss.toNum(-1);
  var pos = 0;

  fun Write(s)
    var l = s.length();
    if pos + l > sz and fn <> nil then
      if pos > 0 then
        Save();
      end if;
      Save(s);
    else
      if pos + l > sz then
        sz *= 2;
        var s = 0.x(sz);
        ss.move(s.toNum(-1));
        ss = s;
        ptr = ss.toNum(-1);
      end if;
      s.move(ptr + pos);
      pos += l;
    end if;
  end fun;

  fun Save(s)
    if s = nil then
      s = ss.substr(len: pos);
      pos = 0;
    end if;
    fn.save(s, cp: cp, append: not first);
    first = false;
  end fun;

  fun Get()
    result = ss.substr(len: pos);
  end fun;
end class;
