
########################################
# lib-ado
########################################
#  Copyright (c) 2017, funlang.org
########################################
use 'lib-set.fun';

var adModeRead = 1;
var adModeShareDenyNone = 16;
#*
var adSchemaCatalogs         = 1;  // ���ݿ�
var adSchemaSchemata         = 17; // Schema
var adSchemaTables           = 20; // ��
var adSchemaColumns          = 4;  // �ֶ�
var adSchemaPrimaryKeys      = 28; // ����
var adSchemaForeignKeys      = 27; // ���
var adSchemaProviderTypes    = 22; // ��������
#
var adSchemaDBInfoLiterals   = 31; // �������

class ADO(cnString, args)
  var db = 'ADODB.Connection'.newobj();
  var cn = cnString;
  var ps = args or [];

  fun Open()
    if ps.mode <> 0 then
      db.Mode = ps.mode; //?. db.Mode;
    end if;
    try
      db.Open(cn);
    except
      raise @ & ' - ' & cn;
    end try;
  end fun;

  fun Close()
    try
      db.Close();
    except
    end try;
  end fun;

  var Closed  () = db = nil or db.State = 0;
  var Begin   () = db.BeginTrans();
  var Commit  () = db.CommitTrans();
  var Rollback() = db.RollbackTrans();

  fun Init()
    var rs = OpenSchema(adSchemaDBInfoLiterals);
    literal('QUOTE', 'quotes');
    literal('SCHEMA_SEPARATOR', 'dot');
    if this.quotes <> nil then
      this.quotes = this.quotes & '%s' & this.quotes;
    end if;

    fun literal(name, prop)
      var s = find(rs, e -> e.LiteralName = name);
      if s <> nil then
        this[prop] = s.LiteralValue;
      end if;
    end fun;
  end fun;

  fun OpenSchema(schema)
    if Closed() then
      Open();
    end if;

    var rs = db.OpenSchema(schema);
    result = rs2json(rs);
  end fun;

  fun Execute(sql, rsNext, stream, from, top, tick)
    if Closed() then
      Open();
    end if;

    var i = 0;
    var rs = db.Execute(sql, var i); // i - AffectedRecords
    if tick <> nil then
      ?. tick.show('exec sql');
    end if;
    if rsNext then
      rs = rs.NextRecordset();
    end if;
    if rs.Fields.Count > 0 then
      result = rs2json(rs, rsNext, stream, from, top, tick);
      if rsNext and result.@count() = 1 then
        result[0].rows = i;
      end if;
    else
      result = new [[rows: i]];
    end if;
  end fun;

  fun ExecuteAndClose(sql)
    try
      if sql =~ /^-?\d++$/ then
        result = OpenSchema(sql div 1);
      else
        result = Execute(sql);
      end if;
    finally
      this.Close();
    end try;
  end fun;

  fun rs2json(rs, rsNext, stream, from, top, tick)
    var fs = rs.Fields;
    result = new [];

    if fs.Count > 0 then
    //try
      if not rs.BOF and not rsNext then
        rs.MoveFirst(); // Execute again when SELECT ...; ...
      end if;
      if from > 0 then
        rs.Move(from);
        if tick <> nil then
          ?. tick.show('move to ' & from);
        end if;
      end if;
      var rsCount = 0;
      if stream <> nil then
        while not rs.EOF do
          for i = 0 to fs.Count-1 do
            if i > 0 then
              stream.Write('\t'.escape());
            end if;
            var v = fs.@Item(i).Value;
            try
              stream.Write(v);
            except
              //?. '$@ at $@@()'.eval();
            end try;
          end do;
          stream.Write('\n'.escape());
          rsCount += 1;
          exit when top > 0 and rsCount >= top;
          rs.MoveNext();
        end do;
      else
        while not rs.EOF do
          var obj = new [];
          result.@add(obj);
          for i = 0 to fs.Count-1 do
            obj[fs.@Item(i).Name] = fs.@Item(i).Value;
          end do;
          rsCount += 1;
          exit when top > 0 and rsCount >= top;
          rs.MoveNext();
        end do;
      end if;
    //except
    //end try;
    end if;
  end fun;
end class;
