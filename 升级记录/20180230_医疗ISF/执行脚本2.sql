create or replace procedure P_PrlYY_ISF_doApp(p_EntGid    varchar2, --企业Gid
                                              p_ModelGid  varchar, --模型Gid
                                              p_FlowGid   varchar, --流程Gid
                                              p_AppAssign varchar2 --意见
                                              ) as
  v_Stage   varchar2(1024); -- 过程场景
  v_ErrText varchar2(1024); -- Oracle错误信息

  v_UsrGid    varchar2(32); --用户Gid
  v_ModelCode varchar2(32); --模型代码
  v_DeptGid   varchar2(32); --当前用户部门

begin
  commit;

  v_Stage := '取出流程信息';
  select f.fillusrgid, f.filldeptgid
    into v_UsrGid, v_DeptGid
    from wf_PrlYY_ISF f
   where f.entgid = p_EntGid
     and f.flowgid = p_FlowGid;

  v_Stage := '取出模型信息';
  select m.code
    into v_ModelCode
    from wf_model m
   where m.Entgid = p_EntGid
     and m.modelgid = p_ModelGid;

  if p_AppAssign <> '终止' then
    --插入审批人
    insert into wf_PrlYY_ISF_App
      (EntGid,
       FlowGid,
       dtlGid,
       AppGid,
       AppCode,
       AppName,
       AppOrder,
       AppType)
      select p_EntGid,
             p_FlowGid,
             sys_guid(),
             v.PostGid AppGid,
             v.PostCode AppCode,
             v.PostName AppName,
             '10' AppOrder,
             '10' AppType
        from v_Post v
       where v.EntGid = p_EntGid
         and v.deptGid = v_DeptGid
         and v.atype = 10
         and rownum = 1
      union
      select p_EntGid,
             p_FlowGid,
             sys_guid(),
             o.AppGid,
             o.AppCode,
             o.AppName,
             o.ModelNote AppOrder,
             o.ModelNote AppType
        from v_wf_model_usr_app o
       where o.EntGid = p_EntGid
         and o.ModelGid = p_ModelGid
         and replace(lower(o.Modelcode), lower(v_ModelCode), '') in
             ('_ta1', '_ta2', '_ta3', '_ta4');
  
    commit;
    --取出审批人中重复的审批人
    delete from wf_PrlYY_ISF_App f
     where f.EntGid = p_EntGid
       and f.FlowGid = p_FlowGid
       and f.Apporder > 0
       and f.Appdate is null
       and not exists (select 1
              from (select max(t.appType) appType,
                           t.EntGid,
                           t.FlowGid,
                           t.AppGid
                      from wf_PrlYY_ISF_App t
                     where t.EntGid = p_EntGid
                       and t.FlowGid = p_FlowGid
                       and t.AppOrder < 100
                       and t.AppDate is null
                     group by t.EntGid, t.FlowGid, t.AppGid) a
             where f.EntGid = a.EntGid
               and f.FlowGid = a.FlowGid
               and f.appType = a.appType);
    v_Stage := '插入审批人';
    if p_AppAssign = '提交' then
      insert into WF_Task
        (EntGid,
         ModelGid,
         FlowGid,
         TaskDefGid,
         TaskGid,
         Stat,
         Code,
         Name,
         Note,
         ExecGid,
         ExecCode,
         ExecName,
         OrderValue,
         IsMCF)
        select p_EntGid,
               p_ModelGid,
               p_FlowGid,
               d.TaskDefGid,
               sys_guid(),
               1,
               d.code,
               d.name,
               d.note,
               a.AppGid,
               a.AppCode,
               a.AppName,
               d.OrderValue,
               d.IsMCF
          from WF_Task_Define d,
               (select *
                  from (select *
                          from wf_PrlYY_ISF_App t
                         where t.entgid = p_EntGid
                           and t.flowgid = p_FlowGid
                           and t.AppOrder <= 100
                           and t.AppDate is null
                         order by t.Apporder)
                 where rownum = 1) a
         where d.EntGid = p_EntGid
           and d.ModelGid = p_ModelGid
           and replace(lower(d.code), lower(v_ModelCode), '') in ('_t2')
           and not exists (select 1
                  from wf_task t
                 where t.entgid = p_EntGid
                   and t.flowgid = p_FlowGid
                   and t.TaskDefGid = d.taskdefgid
                   and t.ExecGid = a.AppGid
                   and t.stat = 1);
    end if;
  end if;
  commit;
  --异常处理
exception
  when others then
    begin
      rollback;
      v_ErrText := substr('流程Gid:' || p_FlowGid || ';用户Gid:' || v_UsrGid || ';' ||
                          v_Stage || ' 失败!' || SQLCode || ':' || SQLERRM,
                          1,
                          1024);
      --插入日志
      insert into Log
        (EntGid,
         EntCode,
         EntName,
         UsrGid,
         UsrCode,
         UsrName,
         CreateDate,
         Atype,
         AContent)
        select e.gid,
               e.code,
               e.name,
               'sys',
               'sys',
               '系统自动',
               sysdate,
               30,
               v_ErrText
          from ent e
         where e.gid = p_EntGid;
      commit;
    end;
end;
/
create or replace procedure P_PrlYY_ISF_doMail(p_FlowGid varchar --流程Gid
                                               ) as
  v_Stage   varchar2(1024); -- 过程场景
  v_ErrText varchar2(1024); -- Oracle错误信息

  v_EntGid varchar2(32); --企业Gid

  v_Title   varchar2(64); --标题
  v_Email   varchar(1024); --邮件
  v_Content varchar2(32500); --内容

  v_Head   varchar(64); --表头
  v_Body   varchar(2048); --表内容
  v_TStart varchar(32);
  v_TEnd   varchar(32);
  v_Foot   varchar(64); --表尾

begin
  -- 获取企业Gid
  v_EntGid  := getEntGid;
  v_Head    := '<table border="0" style="width:500px;"><tr><td>您好 :</td></tr>';
  v_TStart  := '<tr><td>';
  v_TEnd    := '；</td></tr>';
  v_Foot    := '<tr><td>-----------内容展示完毕-----------</td></tr></table>';
  v_Email   := '';
  v_Content := '';
  --for 循环 取出未领取的快递
  for R in (select f.*,
                   substr(wm.code, instr(wm.code, '_', 1) + 1) MCode,
                   wm.name ModelName
              from wf_PrlYY_ISF f, wf_model wm
             where f.EntGid = v_EntGid
               and f.entgid = wm.entgid
               and f.FlowGid = p_FlowGid
               and f.modelgid = wm.modelgid) loop
    v_Stage   := 'FlowGid：' || R.Flowgid || '；模型：' || R.ModelName;
    v_Title   := R.Mcode || '待审提醒:' || R.FilldeptName;
    v_Content := v_Content || v_Head;
  
    v_Body    := '[流程名称] : ' || R.ModelName;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[单号] : ' || R.Num;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[发起人] : ' || R.Fillusrname;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[发起时间] : ' || to_char(R.Createdate, 'YYYY.MM.DD HH24:MI');
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[类别] : ' || R.Atype || R.Category;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[单位] : ' || R.Unit;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[科室] : ' || R.Dept;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[楼层] : ' || R.Floor;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[面积] : ' || R.Area;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[建筑面积] : ' || R.BuildArea;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[租户] : ' || R.Lessee;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[联系人] : ' || R.Contactor;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[地址] : ' || R.Address;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[电话] : ' || R.Phone;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[租赁期限] : ' || R.Leasetermy || '年/' || R.Leasetermm || '月/' ||
                 R.Leasetermd || '日';
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[交付日期] : ' || to_char(R.Handoverdate, 'YYYY.MM.DD');
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[合同起始日期] : ' || to_char(R.Contractdate1, 'YYYY.MM.DD') || '~' ||
                 to_char(R.Contractdate2, 'YYYY.MM.DD');
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[免租期] : ' || R.Freerentm || '月/' || R.Freerentd || '日';
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[装修期] : ' || R.Fitoutm || '月/' || R.Fitoutd || '日（' ||
                 to_char(R.Fitoutdate1, 'YYYY.MM.DD') || '~' ||
                 to_char(R.Fitoutdate2, 'YYYY.MM.DD') || ')';
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[预付租金+费用] : ' || R.AGR;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Body    := '[保证金] : ' || R.Security;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    if R.Rate = '分成' then
      v_Body := R.Rate || '(名医馆:' || R.Rate1 || '%,租户:' || R.Rate2 || '%)';
    else
      v_Body := R.Rate || '(' || R.Rate3 || '元/天';
    end if;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
  
    v_Body := ' <table cellpadding="0" cellspacing="1" class="ListBar" width="100%" style="background-color: #d9dbdf;">';
    v_Body := v_Body || '<col style="width:10%">';
    v_Body := v_Body || '<col style="width:10%">';
    v_Body := v_Body || '<col style="width:15%">';
    v_Body := v_Body || '<col style="width:10%">';
    v_Body := v_Body || '<col style="width:15%">';
    v_Body := v_Body || '<col style="width:10%">';
    v_Body := v_Body || '<col style="width:15%">';
    v_Body := v_Body ||
              '  <tr style="background-color: #ecedef;" align="center">';
    v_Body := v_Body || '    <td colspan="3">第一租赁期固定租金</td>';
    v_Body := v_Body || '    <td colspan="2">物业管理费</td>';
    v_Body := v_Body || '    <td colspan="2">市场推广费</td>';
    v_Body := v_Body || '    <td rowspan="2">操作</td>';
    v_Body := v_Body || ' </tr>';
    v_Body := v_Body ||
              ' <tr style="background-color: #ecedef;" align="center">';
    v_Body := v_Body || '    <td></td>';
    v_Body := v_Body || '    <td>元/天</td>';
    v_Body := v_Body || '    <td>元/月</td>';
    v_Body := v_Body || '    <td>元/天</td>';
    v_Body := v_Body || '    <td>元/月</td>';
    v_Body := v_Body || '    <td>元/天</td>';
    v_Body := v_Body || '    <td>元/月</td>';
    v_Body := v_Body || ' </tr>';
  
    v_Content := v_Content || v_TStart || v_Body;
  
    for D in (select f.*
                from wf_PrlYY_ISF_Dtl f
               where f.EntGid = v_EntGid
                 and f.FlowGid = p_FlowGid
                 and lower(f.TBID) in ('tb_dtl10', 'tb_dtl30')
               order by f.TBID, f.yeartype) loop
      v_Body := ' <tr valign="top" style="background-color: white" align="center">';
      if lower(D.TbId) = 'tb_dtl10' then
        v_Body := v_Body || '<td nowrap> 免:' ||
                  to_char(D.Freerentdate1, 'YYYY.MM.DD') || '~' ||
                  to_char(D.Freerentdate2, 'YYYY.MM.DD') || ') </td>';
      else
        v_Body := v_Body || '<td nowrap> Yr ' || D.Yeartype || ' </td>';
      end if;
      v_Body    := v_Body || '  <td nowrap> ' ||
                   to_char(D.Tbrd, 'FM999999999990.9990') || ' </td>';
      v_Body    := v_Body || '  <td nowrap> ' ||
                   to_char(D.Tbrm, 'FM999999999990.9990') || ' </td>';
      v_Body    := v_Body || '  <td nowrap> ' ||
                   to_char(D.pmfd, 'FM999999999990.9990') || ' </td>';
      v_Body    := v_Body || '  <td nowrap> ' ||
                   to_char(D.pmfm, 'FM999999999990.9990') || ' </td>';
      v_Body    := v_Body || '  <td nowrap> ' ||
                   to_char(D.Progtod, 'FM999999999990.9990') || ' </td>';
      v_Body    := v_Body || '  <td nowrap> ' ||
                   to_char(D.Progtom, 'FM999999999990.9990') || ' </td>';
      v_Body    := v_Body || ' </tr>';
      v_Content := v_Content || v_Body;
    end loop;
  
    v_Body    := '</table>';
    v_Content := v_Content || v_Body || '</td></tr>';
    v_Body    := '[Special Terms and Conditions/Remarks :特别条件/评语] : ' ||
                 R.Memo;
    v_Content := v_Content || v_TStart || v_Body || v_TEnd;
    v_Content := v_Content || v_Foot;
    for U in (select distinct hr.Email
                from hr_emp hr
               where hr.entgid = R.EntGid
                 and exists (select 1
                        from wf_task t
                       where t.EntGid = hr.EntGid
                         and t.FlowGid = R.Flowgid
                         and t.ExecGid = hr.UsrGid
                         and t.Stat = 1)) loop
      v_Email := U.EMAIL || ',';
    end loop;
    if v_Email is not null then
      HDNet_SendMail(v_Title, v_Email, v_Content);
    end if;
  end loop;
  --异常处理
exception
  when others then
    begin
      v_ErrText := substr(v_Stage || ' 失败!' || SQLCode || ':' || SQLERRM,
                          1,
                          1024);
      --插入日志
      insert into Log
        (EntGid,
         EntCode,
         EntName,
         UsrGid,
         UsrCode,
         UsrName,
         CreateDate,
         Atype,
         AContent)
        select e.gid,
               e.code,
               e.name,
               'sys',
               'sys',
               '系统自动',
               sysdate,
               30,
               v_ErrText
          from ent e
         where e.gid = v_EntGid;
      commit;
    end;
end;
/