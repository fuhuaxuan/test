--工作流程执行脚本模板：201403版（此行不允许删除）
--1、定义流程用到的参数名称
declare
  v_EntGid varchar2(32);         --企业Gid
  v_ModelGid varchar2(32);       --工作流程模型Gid
  v_ModelCode varchar2(32);      --工作流程模型代码
  v_TaskGid_T1 varchar2(32);     --开始步骤
  v_TaskGid_Dtl varchar2(32);
  v_TaskGid_Tend varchar2(32);   --结束步骤
  v_Count int;
BEGIN
--2、初始化赋值
  v_TaskGid_T1 := sys_guid();
  v_TaskGid_Dtl := sys_guid();
  v_TaskGid_Tend := sys_guid();

  --获取企业Gid
  select Gid into v_EntGid from Ent where Lower(code) = lower('prlintra');--修改企业Code

  --定义模型代码
  v_ModelCode := 'Prl_OMall';

  --取出当前模型代码对应模型的数量
  select count(*) into v_Count from wf_model where lower(Code) = lower(v_ModelCode) and EntGid = v_EntGid;
  
  --获取模型Gid
  if v_Count = 0 then
    v_ModelGid := sys_guid();
  else
    select ModelGid into v_ModelGid from wf_model where lower(Code) = lower(v_ModelCode) and EntGid = v_EntGid;
  end if;

--3、删除旧有数据信息
  delete from WF_Model where EntGid = v_EntGid and ModelGid = v_ModelGid;
  delete from WF_Task_Define where EntGid = v_EntGid and ModelGid = v_ModelGid;
  delete from WF_Task_Define_Exec where EntGid = v_EntGid and ModelGid = v_ModelGid;
  delete from WF_Task_Define_Condition where EntGid = v_EntGid and ModelGid = v_ModelGid;
  delete from WF_rt where EntGid = v_EntGid and ModelGid = v_ModelGid;
  --delete from WF_Flow where EntGid = v_EntGid and ModelGid = v_ModelGid;
  --delete from WF_Task where EntGid = v_EntGid and ModelGid = v_ModelGid;
  --delete from WF_Task_History where EntGid = v_EntGid and ModelGid = v_ModelGid;

--4、定义工作流程名称 ，步骤等
  insert into WF_Model(EntGid, ModelGid, Code, Name, STAT, CLASSIFY, VERSION, AP1, AP2)
  select v_EntGid, v_ModelGid, v_ModelCode, '写字楼MALL合同新增', 3, '项目审批流程-租赁相关', '2.0', 0, 0 from dual;

  insert into WF_Task_Define(EntGid, ModelGid, TaskDefGid, Code, Name, Note, OrderValue, IsStart, IsEnd, IsMCF)
  select v_EntGid, v_ModelGid, v_TaskGid_T1, v_ModelCode || '_T1', '发起人填写申请单', '填写', 1, 1, 0, 0 from dual;

  insert into WF_Task_Define(EntGid, ModelGid, TaskDefGid, Code, Name, Note, OrderValue, IsStart, IsEnd, IsMCF)
  select v_EntGid, v_ModelGid, v_TaskGid_Tend, v_ModelCode || '_Tend', '流程终止', '结束一个流程', 1, 0, 1, 0 from dual;

  insert into WF_Task_Define(EntGid, ModelGid, TaskDefGid, Code, Name, Note, OrderValue, IsStart, IsEnd, IsMCF)
  select v_EntGid, v_ModelGid, v_TaskGid_Dtl, v_ModelCode, '明细','用于权限用户查看', 1, 0, 0, 0 from dual;

--5、定义工作流程步骤执行人
  insert into WF_Task_Define_Exec(EntGid, ModelGid, TaskDefGid, ExecGidEx, ExecCodeEx, ExecNameEx, OwnerValue)
  select v_EntGid, v_ModelGid, v_TaskGid_T1, Gid, Code, Name, 1 from v_Usr where EntGid = v_EntGid and lower(Code) = lower('all_usr_grp');

  insert into WF_Task_Define_Exec(EntGid, ModelGid, TaskDefGid, ExecGidEx, ExecCodeEx, ExecNameEx, OwnerValue)
  select v_EntGid, v_ModelGid, v_TaskGid_Dtl, Gid, Code, Name, 1 from v_Usr where EntGid = v_EntGid and lower(Code) = lower('all_usr_grp');

  insert into WF_Task_Define_Exec(EntGid, ModelGid, TaskDefGid, ExecGidEx, ExecCodeEx, ExecNameEx, OwnerValue)
  select v_EntGid, v_ModelGid, v_TaskGid_Dtl, '**FlowMember**', '**FlowMember**', '@流程参与人@', 1 from dual;

--6、定义工作流程步骤走向

  insert into WF_Task_Define_Condition(EntGid, ModelGid, FromTaskDef, ToTaskDef)
  select v_EntGid, v_ModelGid, v_TaskGid_T1, v_TaskGid_Tend from dual;

--7、为管理员以及相关人员设置权限
--监视权限  　　 作废权限  　　 变更权限  　　 模型设置权限  
  insert into wf_rt (EntGid, ModelGid, UsrGidEX, RTID)
  select v_EntGid, v_ModelGid, gid, '1111' from org where EntGid = v_EntGid and lower(code) = lower('Admin_Grp');

end;
/

commit;