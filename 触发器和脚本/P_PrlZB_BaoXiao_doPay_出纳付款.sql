create or replace procedure P_PrlZB_Baoxiao_doPay(p_EntGid    varchar2, --企业Gid
                                                  p_ModelGid  varchar, --模型Gid
                                                  p_ModelCode varchar2, --模型代码
                                                  p_FlowGid   varchar, --流程Gid
                                                  p_UsrGid    varchar, --用户Gid
                                                  p_PayDate   date, --支付时间
                                                  p_Certtype  varchar2, --凭证类型
                                                  p_Certnum   varchar2 --凭证编号
                                                  ) as
  v_Stage   varchar2(1024); -- 过程场景
  v_ErrText varchar2(1024); -- Oracle错误信息

  v_UsrCode varchar2(32); --用户
  v_UsrName varchar2(32);

  v_FillUsrGid  varchar2(32); --发起人
  v_FillUsrCode varchar2(32);
  v_FillUsrName varchar2(32);

  v_FromTaskGid varchar2(32); --来源任务Gid
  v_EndTaskGid  varchar2(32); --终止任务Gid
  v_TccTaskGid  varchar2(32); --抄送任务Gid

begin
  if lower(p_ModelCode) = lower('PrlZB_Baoxiao') and p_FlowGid is not null then
    v_Stage := '取出用户信息';
    select v.Code, v.Name
      into v_UsrCode, v_UsrName
      from v_usr v
     where v.EntGid = p_EntGid
       and v.Gid = p_UsrGid;
  
    v_Stage := '取出发起人信息';
    select v.CREATERGID, v.CREATERCode, v.CREATERName
      into v_FillUsrGid, v_FillUsrCode, v_FillUsrName
      from wf_flow v
     where v.EntGid = p_EntGid
       and v.FlowGid = p_FlowGid;
  
    v_Stage := '得到抄送任务的任务定义Gid';
    select TaskDefGid
      into v_TccTaskGid
      from WF_Task_Define
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid
       and lower(Code) = lower('PrlZB_Baoxiao_Tcc');
  
    v_Stage := '得到来源任务的任务定义Gid';
    select TaskDefGid
      into v_FromTaskGid
      from WF_Task_Define
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid
       and lower(Code) = lower('PrlZB_Baoxiao_t5')
       and IsMcf = 0;
  
    v_Stage := '得到当前的流程终止任务的Gid';
    select TaskDefGid
      into v_EndTaskGid
      from WF_Task_Define
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid
       and IsEnd = 1;
  
    v_Stage := '更新主表';
    update WF_PrlZB_Baoxiao
       set (LastUpdDate, Stat, CertType, CertNum, PayDate) =
           (select sysdate, '已完成', p_Certtype, p_Certnum, p_PayDate
              from dual)
     where EntGid = p_EntGid
       AND FlowGid = p_FlowGid;
  
    v_Stage := '插入审批人';
    insert into WF_PrlZB_Baoxiao_App
      (EntGid,
       ModelGid,
       FlowGid,
       Gid,
       AppGid,
       AppCode,
       AppName,
       AppType,
       AppOrder,
       AppAssign,
       AppMemo,
       AppDate)
      select p_EntGid,
             p_ModelGid,
             p_FlowGid,
             sys_guid(),
             p_UsrGid,
             v_UsrCode,
             v_UsrName,
             90,
             90,
             '确认付款',
             '',
             sysdate
        from dual;
  
    v_Stage := '更新FromTask的状态为3';
    update WF_Task
       set Stat = 3, ETime = sysdate
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid
       and FlowGid = p_FlowGid
       and TaskDefGid = v_FromTaskGid
       and ExecGid = p_UsrGid
       and IsMcf = 0;
  
    v_Stage := '更新流程的实例状态';
    update WF_Flow
       set Stat = 3, LastUpdDate = sysdate, FinishDate = sysdate
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid
       and FlowGid = p_FlowGid;
  
    v_Stage := '更新流程的实例中所有未完成任务的状态';
    update WF_Task
       set Stat = 4, ETime = sysdate
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid
       and FlowGid = p_FlowGid
       and Stat < 3
       and IsMcf = 0;
  
    v_Stage := '创建抄送任务';
    insert into WF_Task
      (EntGid,
       ModelGid,
       FlowGid,
       TaskDefGid,
       TaskGid,
       Code,
       Name,
       Note,
       Stat,
       ExecGid,
       ExecCode,
       ExecName,
       OrderValue,
       IsMCF)
      select p_EntGid,
             p_ModelGid,
             p_FlowGid,
             v_TccTaskGid,
             sys_guid(),
             Code,
             Name,
             Note,
             1,
             v_FillUsrGid,
             v_FillUsrCode,
             v_FillUsrName,
             OrderValue,
             IsMCF
        from WF_Task_Define
       where EntGid = p_EntGid
         and ModelGid = p_ModelGid
         and TaskDefGid = v_TccTaskGid;
  
    v_Stage := '创建流程结束任务';
    insert into WF_Task
      (EntGid,
       ModelGid,
       FlowGid,
       TaskDefGid,
       TaskGid,
       Code,
       Name,
       Note,
       Stat,
       ExecGid,
       ExecCode,
       ExecName,
       OrderValue)
      select p_EntGid,
             p_ModelGid,
             p_FlowGid,
             v_EndTaskGid,
             sys_guid(),
             Code,
             Name,
             Note,
             3,
             p_UsrGid,
             v_UsrCode,
             v_UsrName,
             OrderValue
        from WF_Task_Define
       where EntGid = p_EntGid
         and ModelGid = p_ModelGid
         and TaskDefGid = v_EndTaskGid;
  
    v_Stage := 'WF_Model.Ap2 - 1;WF_Model.Ap1 + 1';
    update WF_Model
       set Ap2 = Ap2 - 1, Ap1 = Ap1 + 1, LastUpdDate = sysdate
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid;
  
    v_Stage := '将WF_Task表中的该实例信息加入WF_Task_History，删除WF_Task表中的该实例信息';
    insert into WF_Task_History
      select *
        from WF_Task
       where EntGid = p_EntGid
         and ModelGid = p_ModelGid
         and FlowGid = p_FlowGid
         and Stat <= 6
         and IsMcf = 0;
  
    v_Stage := '删除流程的任务记录';
    delete from WF_Task
     where EntGid = p_EntGid
       and ModelGid = p_ModelGid
       and FlowGid = p_FlowGid
       and IsMcf = 0;
  
    commit;
  end if;
  --异常处理
exception
  when others then
    begin
      rollback;
      v_ErrText := substr('流程Gid:' || p_FlowGid || ';用户Gid:' || p_UsrGid ||
                          '批量付款;' || v_Stage || ' 失败!' || SQLCode || ':' ||
                          SQLERRM,
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
