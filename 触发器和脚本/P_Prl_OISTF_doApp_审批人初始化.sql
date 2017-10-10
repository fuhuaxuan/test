create or replace procedure P_Prl_OISTF_doApp(p_EntGid    varchar2, --企业Gid
                                              p_ModelGid  varchar, --模型Gid
                                              p_FlowGid   varchar, --流程Gid
                                              p_AppAssign varchar2 --意见
                                              ) as
  v_Stage   varchar2(1024); -- 过程场景
  v_ErrText varchar2(1024); -- Oracle错误信息

  v_UsrGid      varchar2(32); --用户Gid
  v_ModelCode   varchar2(32); --模型代码
  v_DeptGid     varchar2(32); --当前用户部门
  v_PreDeptCode varchar2(32); --所属部门代码

  v_AppFee number(20, 2);
begin
  commit;
  v_Stage := '取出流程信息';
  select nvl(numa, 0) + nvl(numb, 0) + nvl(numc, 0) + nvl(numd, 0) +
         nvl(numg, 0),
         f.FillUsrGid,
         f.filldeptgid,
         substr(f.filldeptcode, 0, 4)
    into v_AppFee, v_UsrGid, v_DeptGid, v_PreDeptCode
    from wf_Prl_OISTF f
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
    insert into wf_Prl_OISF_App
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
             t.AppGid,
             t.AppCode,
             t.AppName,
             t.AppOrder,
             t.AppType
        from (select v.PostGid  AppGid,
                     v.PostCode AppCode,
                     v.PostName AppName,
                     10         AppOrder,
                     10         AppType
                from v_Post v
               where v.EntGid = p_EntGid
                 and v.deptGid = v_DeptGid
                 and v.atype = 10
                 and rownum = 1
              union
              select v.PostGid  AppGid,
                     v.PostCode AppCode,
                     v.PostName AppName,
                     30         AppOrder,
                     30         AppType
                from v_Post v
               where v.EntGid = p_EntGid
                 and v.deptGid = v_DeptGid
                 and v.atype = 30
                 and rownum = 1
              union
              select v.PostGid  AppGid,
                     v.PostCode AppCode,
                     v.PostName AppName,
                     40         AppOrder,
                     40         AppType
                from v_Post v
               where v.EntGid = p_EntGid
                 and v.deptGid = v_DeptGid
                 and v.atype = 40
                 and rownum = 1
              union
              select v.PostGid  AppGid,
                     v.PostCode AppCode,
                     v.PostName AppName,
                     50         AppOrder,
                     50         AppType
                from v_Post v
               where v.EntGid = p_EntGid
                 and v.deptGid = v_DeptGid
                 and v.atype = 71
                 and rownum = 1
              union
              select o.AppGid, o.AppCode, o.AppName, 60 AppOrder, 60 AppType
                from v_wf_model_usr_app o
               where o.EntGid = p_EntGid
                 and o.ModelGid = p_ModelGid
                 and replace(lower(o.Modelcode), lower(v_ModelCode), '') in
                     ('_tb2')
                 and rownum = 1
              union
              select o.AppGid, o.AppCode, o.AppName, 80 AppOrder, 80 AppType
                from v_wf_model_usr_app o
               where o.EntGid = p_EntGid
                 and o.ModelGid = p_ModelGid
                 and replace(lower(o.Modelcode), lower(v_ModelCode), '') in
                     ('_tc1')
                 and rownum = 1
                 and v_AppFee > 80000
              union
              select v.PostGid  AppGid,
                     v.PostCode AppCode,
                     v.PostName AppName,
                     90         AppOrder,
                     90         AppType
                from v_Post v
               where v.EntGid = p_EntGid
                 and v.deptGid = v_DeptGid
                 and v.atype = 80
                 and rownum = 1
                 and v_AppFee > 80000
              union
              select o.AppGid, o.AppCode, o.AppName, 95 AppOrder, 95 AppType
                from v_wf_model_usr_app o
               where o.EntGid = p_EntGid
                 and o.ModelGid = p_ModelGid
                 and replace(lower(o.Modelcode), lower(v_ModelCode), '') in
                     ('_tc3')
                 and rownum = 1
                 and v_AppFee > 80000
              union
              select o.AppGid,
                     o.AppCode,
                     o.AppName,
                     100       AppOrder,
                     100       AppType
                from v_wf_model_usr_app o
               where o.EntGid = p_EntGid
                 and o.ModelGid = p_ModelGid
                 and replace(lower(o.Modelcode), lower(v_ModelCode), '') in
                     ('_td')
                 and rownum = 1
                 and v_AppFee > 300000) t;
  
    commit;
    --取出审批人中重复的审批人
    delete from wf_Prl_OISF_App f
     where f.EntGid = p_EntGid
       and f.FlowGid = p_FlowGid
       and f.Apporder > 0
       and f.Appdate is null
       and not exists (select 1
              from (select max(t.appType) appType,
                           t.EntGid,
                           t.FlowGid,
                           t.AppGid
                      from wf_Prl_OISF_App t
                     where t.EntGid = p_EntGid
                       and t.FlowGid = p_FlowGid
                       and t.AppOrder <= 100
                       and t.AppDate is null
                     group by t.EntGid, t.FlowGid, t.AppGid) a
             where f.EntGid = a.EntGid
               and f.FlowGid = a.FlowGid
               and f.appType = a.appType);
  end if;
  commit;
  --异常处理
exception
  when others then
    begin
      rollback;
      v_ErrText := substr('流程Gid:' || p_FlowGid || ';用户Gid:' || v_UsrGid ||
                          ';金额:' || v_AppFee || ';' || v_Stage || ' 失败!' ||
                          SQLCode || ':' || SQLERRM,
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