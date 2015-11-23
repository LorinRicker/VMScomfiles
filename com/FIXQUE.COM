$!  Copyright (c) 1991,1992 Digital Equipment Corporation.  All rights reserved.
$! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
$! Procedure to try and gather all possible information out of an existing
$! queue file, to prepare for an attempt at recovery.
$!
$! As output, creates a command procedure called FIXQUE_RELOAD.COM which can
$! be run to restore the previously existing queues, jobs, characteristics,
$! and form definitions after creating a new, empty queue file.
$!
$! Parameters to control operation, mostly for testing:
$!      V4      Parse assuming VMS 4.x SHOW QUEUE listing format
$!      V5      Parse assuming VMS 5.x SHOW QUEUE listing format (x=0,1,2,3,4)
$!      V5.5    Parse assuming VMS 5.5 or later SHOW QUEUE listing format
$!         (default is to look at the running system to determine version)
$!      RERUN   Run using old .LIST files from a previous run
$!
$!                                               Keith B. Parris 5/89,10/91,9/92
$!                                               keith.parris@zko.mts.dec.com
$! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
$close/nolog chars
$close/nolog forms
$close/nolog queue
$close/nolog jobs
$close/nolog generic
$close/nolog start
$close/nolog com
$parameters=f$ed(" ''p1' ''p2' ''p3' ''p4' ''p5' ''p6' ''p7' ''p8' ","UPCASE,COMPRESS")
$if parameters.eqs." " then parameters="(none)"
$param_len=f$le(parameters)
$rerun=f$loc(" RER",parameters).ne.param_len
$vms_version=f$ed(f$gets("VERSION"),"TRIM")
$version=55
$if f$ex(1,2,vms_version).eqs."4." then version=4
$vms_version_number=f$el(0,"-",f$ex(1,9,vms_version))
$if vms_version_number.eqs."5.0".or.vms_version_number.eqs."5.1".or.vms_version_number.eqs."5.2".or.vms_version_number.eqs."5.3".or-
.vms_version_number.eqs."5.4" then version=5
$if f$loc(" V4 ",parameters).ne.param_len then version=4
$if f$loc(" V5 ",parameters).ne.param_len then version=5
$if f$loc(" V5.5 ",parameters).ne.param_len then version=55
$if_v4="!"
$if_v5="!"
$if_v55="!"
$if_v'version'=""
$if_not_v4=""
$if_not_v5=""
$if_not_v55=""
$if_not_v'version'="!"
$old_priv=""
$if rerun then goto GOT_PRIVS
$old_priv=f$set("OPER")
$if f$pri("OPER") then goto GOT_PRIVS
$write sys$output "OPER privilege is required to run this procedure."
$exit
$GOT_PRIVS:got_error="FALSE"
$not_in_dir="FALSE"
$open/write com FIXQUE_RELOAD.COM
$write com "$! FIXQUE_RELOAD.COM, created by FIXQUE.COM version T1.8-1"
$write com "$! under VMS version ",vms_version,".  Parameters: ",f$ed(parameters,"TRIM")
$write com "$X=F$SETPRV(""CMKRNL,OPER,SYSPRV"")"
$write com "$IF F$PRIVILEGE(""CMKRNL,OPER,SYSPRV"") THEN GOTO PRIV_OK"
$write com "$WRITE SYS$OUTPUT ","""You need CMKRNL, OPER, and SYSPRV privileges."""
$write com "$EXIT"
$write com "$PRIV_OK:"
$write com "$SET NOON"
$on error then goto CHAR_ERR
$if.not.rerun then write sys$output "Doing $SHOW QUEUE/CHARACTERISTICS"
$if.not.rerun then show queue/CHARACTERISTICS/output=fixque_CHARS.list
$on error then exit
$goto GOT_CHAR_INFO
$CHAR_ERR:err_code=$status
$on error then exit
$err_msg=f$me(err_code)
$if err_msg.eqs."%JBC-E-NOSUCHCHAR, no such characteristic" then goto C_NONE
$write sys$output "FIXQUE: Encountered error ",err_msg
$write sys$output "doing $SHOW QUEUE/CHARACTERISTICS/OUTPUT=FIXQUE_CHARS.LIST"
$exit
$C_NONE:close/nolog chars
$write sys$output "No characteristics found"
$write com "$WRITE SYS$OUTPUT ""No characteristics defined."""
$goto C_DONE
$GOT_CHAR_INFO:list_file="FIXQUE_CHARS.LIST"
$open/read chars 'list_file'
$read/end=C_NONE chars record
$list_record=1
$write sys$output "Parsing characteristics..."
$write com "$ASK_CHARS:"
$write com "$INQUIRE ANS ""Do you wish to recreate characteristics? [Y]"""
$write com "$ANS=F$EXTRACT(0,1,F$EDIT(ANS,""TRIM,UPCASE""))"
$write com "$IF ANS .EQS. ""N"" THEN GOTO DONE_CHARS"
$write com "$IF ANS .NES. """" .AND. ANS .NES. ""Y"" THEN GOTO ASK_CHARS"
$write com "$WRITE SYS$OUTPUT ""Defining characteristics"""
$if f$ex(0,19,record).nes."Characteristic name" then goto SHOW_ERROR
$read/end=SHOW_ERROR chars record
$list_record=2
$if f$ex(0,19,record).nes."-------------------" then goto SHOW_ERROR
$C_LOOP_1:read/end=C_EOF chars record
$list_record=list_record + 1
$if record.eqs."" then goto SHOW_ERROR
$if f$ex(0,1,record).eqs." " then goto SHOW_ERROR
$char_name=f$ed(f$ex(0,32,record),"TRIM")
$char_number=f$ed(f$ex(33,10,record),"TRIM")
$if f$ty(char_number).nes."INTEGER" then goto SHOW_ERROR
$write sys$output "  Characteristic ",char_name
$write com "$DEFINE/CHARACTERISTIC ",char_name," ",char_number
$goto C_LOOP_1
$C_EOF:write com "$DONE_CHARS:"
$close chars
$C_DONE:on error then goto FORM_ERR
$if.not.rerun then write sys$output "Doing $SHOW QUEUE/FORM/FULL"
$if.not.rerun then show queue/FORM/full/output=fixque_FORMS.list
$on error then exit
$goto GOT_FORM_INFO
$FORM_ERR:err_code=$status
$on error then exit
$err_msg=f$me(err_code)
$if err_msg.eqs."%JBC-E-NOSUCHFORM, no such form" then goto F_NONE
$write sys$output "FIXQUE: Encountered error ",err_msg
$write sys$output "doing $SHOW QUEUE/FORM/FULL/OUTPUT=FIXQUE_FORMS.LIST"
$exit
$F_NONE:close/nolog forms
$write sys$output "No forms found"
$write com "$WRITE SYS$OUTPUT ""No forms defined."""
$goto F_DONE
$GOT_FORM_INFO:list_file="FIXQUE_FORMS.LIST"
$open/read forms 'list_file'
$read/end=F_NONE forms record
$list_record=1
$write sys$output "Parsing form definitions..."
$write com "$ASK_FORMS:"
$write com "$INQUIRE ANS ""Do you wish to recreate form definitions? [Y]"""
$write com "$ANS=F$EXTRACT(0,1,F$EDIT(ANS,""TRIM,UPCASE""))"
$write com "$IF ANS .EQS. ""N"" THEN GOTO DONE_FORMS"
$write com "$IF ANS .NES. """" .AND. ANS .NES. ""Y"" THEN GOTO ASK_FORMS"
$write com "$WRITE SYS$OUTPUT ""Defining forms"""
$if f$ex(0,9,record).nes."Form name" then goto SHOW_ERROR
$read/end=SHOW_ERROR forms record
$list_record=2
$if f$ex(0,9,record).nes."---------" then goto SHOW_ERROR
$F_LOOP_1:read/end=F_EOF forms record
$list_record=list_record + 1
$F_CONT_1:if record.eqs."" then goto SHOW_ERROR
$if f$ex(0,1,record).eqs." " then goto SHOW_ERROR
$form_name=f$ed(f$ex(0,32,record),"TRIM")
$f_notruncate="TRUE"
$f_bottom="TRUE"
$if f$ex(43,3,record).nes."   " then goto F_2_2LINE
$F_2_2LINE_1:fn_len=f$le(form_name)
$if f$loc("/",form_name).ne.fn_len then goto SHOW_ERROR
$t=f$loc(" (",form_name)
$if t.ne.fn_len then form_name=f$ex(0,t,form_name)
$form_number=f$ed(f$ex(33,10,record),"TRIM")
$if f$ty(form_number).nes."INTEGER" then goto SHOW_ERROR
$form_desc=f$ex(46,999,record)
$form_line="$DEFINE/FORM/DESCRIPTION=""" + form_desc + """"
$write sys$output "  Form ",form_name
$F_LOOP_2:read/end=F_END_2 forms record
$list_record=list_record + 1
$if record.eqs."" then goto F_END_2
$if f$ex(0,5,record).nes."    /" then goto SHOW_ERROR
$i=1
$F_LOOP_2A:qualifier=f$ed(f$el(i,"/",record),"TRIM")
$if qualifier.eqs."/" then goto F_LOOP_2
$i=i + 1
$if qualifier.eqs."TRUNCATE".or.qualifier.eqs."WRAP" then f_notruncate="FALSE"
$if f$ex(0,6,qualifier).eqs."MARGIN" then goto F_2_MARGIN
$F_2_MARGIN_DONE:if (form_line.eqs."   ").or.(f$le(form_line) + f$le(qualifier).le.77) then goto F_2_ADD_QUAL
$write com form_line,"-"
$form_line="   "
$F_2_ADD_QUAL:form_line=form_line + "/" + qualifier
$goto F_LOOP_2A
$F_2_2LINE:form_name=record
$read/end=SHOW_ERROR forms record
$list_record=list_record + 1
$if f$ex(0,33,record).nes."                                 " then goto SHOW_ERROR
$goto F_2_2LINE_1
$F_2_MARGIN:f_bottom="FALSE"
$if f$loc("BOTTOM",qualifier).eq.f$le(qualifier) then qualifier=qualifier - ")" + ",BOTTOM=0)"
$goto F_2_MARGIN_DONE
$F_END_2:if.not.f_notruncate then goto F_E2_NOTR2
$if (form_line.eqs."   ").or.(f$le(form_line) + 10.le.77) then goto F_E2_NOTR1
$write com form_line,"-"
$form_line="   "
$F_E2_NOTR1:form_line=form_line + "/NOTRUNCATE"
$F_E2_NOTR2:if.not.f_bottom then goto F_E2_BOTT2
$if (form_line.eqs."   ").or.(f$le(form_line) + 17.le.77) then goto F_E2_BOTT1
$write com form_line,"-"
$form_line="   "
$F_E2_BOTT1:form_line=form_line + "/MARGIN=(BOTTOM=0)"
$F_E2_BOTT2:if (f$le(form_line) + f$le(form_name) + f$le(form_number)).le.77 then goto F_E2A
$write com form_line,"-"
$form_line="     "
$F_E2A:write com form_line," ",form_name," ",form_number
$goto F_LOOP_1
$F_EOF:write com "$DONE_FORMS:"
$close forms
$F_DONE:on error then goto QUEUE_ERR
$if.not.rerun then write sys$output "Doing $SHOW QUEUE/ALL/FULL"
$if.not.rerun then show queue/all/full/output=fixque_QUEUE.list
$on error then exit
$goto GOT_QUEUE_INFO
$QUEUE_ERR:err_code=$status
$on error then exit
$err_msg=f$me(err_code)
$if err_msg.eqs."%JBC-E-NOSUCHQUE, no such queue" then goto Q_NONE
$write sys$output "FIXQUE: Encountered error ",err_msg
$write sys$output "doing $SHOW QUEUE/ALL/FULL/OUTPUT=FIXQUE_QUEUE.LIST"
$exit
$Q_NONE:close/nolog queue
$write sys$output "No queues found"
$write com "$WRITE SYS$OUTPUT ""No queues defined."""
$goto Q_DONE
$GOT_QUEUE_INFO:list_file="FIXQUE_QUEUE.LIST"
$open/read queue 'list_file'
$read/end=Q_NONE queue record
$list_record=1
$write sys$output "Parsing queues and jobs..."
$open/write generic FIXQUE_QUEUE_GENERIC.TEMP
$open/write jobs FIXQUE_QUEUE_JOBS.TEMP
$open/write start FIXQUE_QUEUE_START.TEMP
$write com "$ASK_QUEUE:"
$write com "$INQUIRE ANS ""Do you wish to recreate queues? [Y]"""
$write com "$ANS=F$EXTRACT(0,1,F$EDIT(ANS,""TRIM,UPCASE""))"
$write com "$IF ANS .EQS. """" THEN ANS = ""Y"""
$write com "$IF ANS .NES. ""N"" .AND. ANS .NES. ""Y"" THEN GOTO ASK_QUEUE"
$write com "$IF .NOT. ANS THEN GOTO DONE_QUEUES"
$write com "$WRITE SYS$OUTPUT ""Recreating queues"""
$write jobs "$ASK_JOB:"
$write jobs "$INQUIRE ANS ""Do you wish to recreate print and batch jobs? [Y]"""
$write jobs "$ANS=F$EXTRACT(0,1,F$EDIT(ANS,""TRIM,UPCASE""))"
$write jobs "$IF ANS .EQS. """" THEN ANS = ""Y"""
$write jobs "$IF ANS .NES. ""N"" .AND. ANS .NES. ""Y"" THEN GOTO ASK_JOB"
$write jobs "$IF .NOT. ANS THEN GOTO DONE_JOBS"
$write jobs "$WRITE SYS$OUTPUT ""Recreating jobs"""
$queue_type_phrases=";Batch queue " + ";Generic batch queue " + ";Printer queue " + ";Generic printer queue " + ";Terminal queue " -
+ ";Remote terminal queue " + ";Generic terminal queue " + ";Server queue " + ";Generic server queue " + ";Output queue " + -
";Logical queue "
$queue_type_phrase_len=";12" + -
                ";20" + -       !"Generic batch queue "
                ";14" + -       !"Printer queue "
                ";22" + -       !"Generic printer queue "
                ";15" + -       !"Terminal queue "
                ";22" + -       !"Remote terminal queue "
                ";23" + -       !"Generic terminal queue "
                ";13" + -       !"Server queue "
                ";21" + -       !"Generic server queue "
                ";13" + -       !"Output queue "
                ";14"           !"Logical queue "
$queue_type_qualifiers=";/BATCH" + -
                ";/BATCH/GENERIC" + -           !Generic batch queue
                ";/DEVICE=PRINTER" + -          !Printer queue
                ";/DEVICE=PRINTER/GENERIC" + -  !Generic printer queue
                ";/DEVICE=TERMINAL" + -         !Terminal queue
                ";/DEVICE=TERMINAL" + -         !Remote terminal queue
                ";/DEVICE=TERMINAL/GENERIC" + - !Generic terminal queue
                ";/DEVICE=SERVER" + -           !Server queue
                ";/DEVICE=SERVER/GENERIC" + -   !Generic server queue
                ";/DEVICE" + -                  !Output queue
                ";"                             !Logical queue
$if version.eq.4 then queue_type_qualifiers=";/BATCH" + -
                ";/BATCH/GENERIC" + -                   !Generic batch queue
                ";" + -                 !/PRINTER       !Printer queue
                ";/GENERIC" + -         !/PRINTER       !Generic printer queue
                ";/TERMINAL" + -                        !Terminal queue
                ";/TERMINAL" + -                        !Remote terminal queue
                ";/TERMINAL/GENERIC" + -                !Generic terminal queue
                ";" + -                 !/DEVICE=SERVER !Server queue
                ";/GENERIC" + -         !/DEVICE=SERVER !Generic server queue
                ";" + -                 !/DEVICE        !Output queue
                ";"                                     !Logical queue
$queue_type_generic=" " + "F" + -
                "T" + - !Generic batch queue
                "F" + - !Printer queue
                "T" + - !Generic printer queue
                "F" + - !Terminal queue
                "F" + - !Remote terminal queue
                "T" + - !Generic terminal queue
                "F" + - !Server queue
                "T" + - !Generic server queue
                "F" + - !Output queue
                "F"     !Logical queue
$'if_not_v55 ace_blank_cnt=10
$'if_v55 ace_blank_cnt=9
$ace_blanks=f$ex(0,ace_blank_cnt,"          ")
$'if_not_v55 job_hdr="  Jobname         Username     Entry"
$'if_v55 job_hdr="  Entry  Jobname         Username"
$job_hdr_len=f$le(job_hdr)
$'if_not_v55 job_hdr2="  -------         --------     -----"
$'if_v55 job_hdr2="  -----  -------         --------"
$job_hdr2_len=f$le(job_hdr2)
$'if_not_v55 cont_blank_cnt=18
$'if_v55 cont_blank_cnt=25
$cont_blanks=f$ex(0,cont_blank_cnt,"                         ")
$'if_not_v55 leading_blank_cnt=4
$'if_v55 leading_blank_cnt=9
$leading_blanks=f$ex(0,leading_blank_cnt,"         ")
$'if_v4 file_prefix="  "
$'if_not_v4 file_prefix="File:"
$file_prefix_len=f$le(file_prefix)
$'if_not_v55 error_blank_cnt=4
$'if_v55 error_blank_cnt=7
$error_blanks=f$ex(0,error_blank_cnt,"       ")
$Q_LOOP_1:parsing_job="FALSE"
$i=0
$Q_LOOP_1T:i=i + 1
$next_queue_type_phrase=f$el(i,";",queue_type_phrases)
$if next_queue_type_phrase.eqs.";" then goto SHOW_ERROR
$qtp_len=f$el(i,";",queue_type_phrase_len)
$if f$ex(0,qtp_len,record).nes.next_queue_type_phrase then goto Q_LOOP_1T
$queue_type=f$el(i,";",queue_type_qualifiers)
$q_out="COM"
$if f$ex(i,1,queue_type_generic) then q_out="GENERIC"
$q_nofeed="TRUE"
$if q_out.eqs."GENERIC" then q_nofeed="FALSE"
$if f$loc("BATCH",queue_type).ne.qtp_len then q_nofeed="FALSE"
$trec=f$ex(qtp_len,999,record)
$qt_len=f$le(queue_type)
$queue_name=f$el(0,",",trec)
$write sys$output "  Queue ",queue_name
$queue_line="$INITIALIZE/QUEUE" + queue_type
$queue_start="/START"
$logical_queue=""
$i=1
$Q_LOOP_1A:phrase=f$el(i,",",trec)
$if phrase.eqs."," then goto Q_END_1A
$i=i + 1
$if f$ex(0,4,phrase).eqs." on " then goto Q_1A_ON
$if f$ex(0,13,phrase).eqs." mounted form" then goto Q_1A_FORM
$if f$ex(0,12,phrase).eqs." assigned to" then goto Q_1A_LOGICAL
$if f$ex(0,7,phrase).eqs." paused" then goto Q_NOSTART
$if f$ex(0,8,phrase).eqs." stopped" then goto Q_NOSTART
$if f$ex(0,9,phrase).eqs." stopping" then goto Q_NOSTART
$if f$ex(0,10,phrase).eqs." resetting" then goto Q_NOSTART
$if f$ex(0,19,phrase).eqs." device unavailable" then goto Q_NOSTART
$if f$ex(0,8,phrase).eqs." stalled" then goto Q_NOSTART
$if f$ex(0,9,phrase).eqs." starting" then goto Q_INFO
$if f$ex(0,7,phrase).eqs." closed" then goto Q_CLOSED
$'if_v55 if f$ex(0,5,phrase).eqs." idle" then goto Q_LOOP_1A
$'if_v55 if f$ex(0,5,phrase).eqs." busy" then goto Q_LOOP_1A
$'if_v55 if f$ex(0,10,phrase).eqs." available" then goto Q_LOOP_1A
$write sys$output "  ...unrecognized phrase ignored: ",phrase
$goto Q_LOOP_1A
$Q_INFO:write sys$output "  ...is in",phrase," state"
$goto Q_LOOP_1A
$Q_NOSTART:message="and will not be started by FIXQUE_RELOAD.COM"
$if queue_start.eqs."/NOSTART" then message="as well"
$write sys$output "  ...is in",phrase," state ",message
$message=message - " by FIXQUE_RELOAD.COM"
$write start "$WRITE SYS$OUTPUT ""Queue ",queue_name," was in",phrase," state ",message,""""
$queue_start="/NOSTART"
$goto Q_LOOP_1A
$Q_CLOSED:write sys$output "  ...is in a closed state and will be reclosed after"
$write sys$output "     any jobs found have been resubmitted"
$write start "$WRITE SYS$OUTPUT ""Queue ",queue_name," closed"
$write start "$SET QUEUE/CLOSE ",queue_name
$goto Q_LOOP_1A
$Q_1A_LOGICAL:phrase=phrase - " assigned to "
$logical_queue=phrase
$goto Q_LOOP_1A
$Q_1A_ON:qualifier="ON=" + (phrase - " on ")
$goto Q_1A_QUAL
$Q_1A_FORM:phrase=phrase - " mounted form "
$if f$loc(" (stock=",phrase).ne.f$le(phrase) then phrase=f$el(0," ",phrase)
$qualifier="FORM_MOUNTED=" + phrase
$Q_1A_QUAL:q_len=f$le(qualifier)
$if (queue_line.eqs."   ").or.(f$le(queue_line) + q_len.le.77) then goto Q_1A_ADD_QUAL
$write 'q_out' queue_line,"-"
$queue_line="   "
$Q_1A_ADD_QUAL:queue_line=queue_line + "/" + qualifier
$goto Q_LOOP_1A
$Q_END_1A:queue_qual=""
$Q_LOOP_1B:read/end=Q_1B_1 queue record
$list_record=list_record + 1
$if record.eqs."" then goto Q_1B_1
$if f$ex(0,ace_blank_cnt+12,record).eqs.ace_blanks+"(IDENTIFIER=" then goto Q_1B_1
$if f$ex(0,1,record).eqs."<".and.f$ex(f$le(record)-1,1,record).eqs.">" then goto Q_1B_0
$queue_qual=queue_qual + f$ed(record,"TRIM")
$goto Q_LOOP_1B
$Q_1B_0:qualifier="DESCRIPTION=""" + f$ex(1,f$le(record)-2,record) + """"
$q_len=f$le(qualifier)
$if (queue_line.eqs."   ").or.(f$le(queue_line) + q_len.le.77) then goto Q_1B0_ADD_QUAL
$write 'q_out' queue_line,"-"
$queue_line="   "
$Q_1B0_ADD_QUAL:queue_line=queue_line + "/" + qualifier
$goto Q_LOOP_1B
$Q_1B_1:i=1
$Q_LOOP_1C:qualifier=f$ed(f$el(i,"/",queue_qual),"TRIM")
$if qualifier.eqs."/" then goto Q_END_1B
$i=i + 1
$q_len=f$le(qualifier)
$if f$loc(" ",qualifier).ne.q_len then goto Q_1C_QUAL_SPC
$Q_1C_QUAL_NOSPC:if f$ex(0,7,qualifier).eqs."GENERIC" then queue_line=queue_line - "/GENERIC"
$if f$ex(0,7,qualifier).eqs."DEFAULT" then goto Q_CHK_NOFEED
$Q_CHK_NOFEED_DONE:if (queue_line.eqs."   ").or.(f$le(queue_line) + q_len.le.77) then goto Q_1C_ADD_QUAL
$write 'q_out' queue_line,"-"
$queue_line="   "
$Q_1C_ADD_QUAL:queue_line=queue_line + "/" + qualifier
$goto Q_LOOP_1C
$Q_1C_QUAL_SPC:if f$loc(" Lowercase",qualifier).ne.q_len then goto CQ_LOWER
$Q_1C_CHK_STOCK:t1=f$loc(" (stock=",qualifier)
$if t1.ne.q_len then goto CQ_STOCK
$goto Q_1C_QUAL_NOSPC
$CQ_LOWER:qualifier=qualifier - " Lowercase"
$q_len=f$le(qualifier)
$goto Q_1C_CHK_STOCK
$CQ_STOCK:t2=f$loc(")",qualifier) + 1
$qualifier=f$ex(0,t1,qualifier) + f$ex(t2,(q_len-t2),qualifier)
$q_len=f$le(qualifier)
$goto Q_1C_QUAL_NOSPC
$Q_CHK_NOFEED:q_nofeed="FALSE"
$if f$loc("(FEED,",qualifier).ne.f$le(qualifier) then goto Q_CHK_NOFEED_DONE
$if f$loc(",FEED,",qualifier).ne.f$le(qualifier) then goto Q_CHK_NOFEED_DONE
$qualifier=qualifier - ")" + ",NOFEED)"
$goto Q_CHK_NOFEED_DONE
$Q_END_1B:if.not.q_nofeed then goto Q_NOFEED2
$if (queue_line.eqs."   ").or.(f$le(queue_line) + 16.le.77) then goto Q_NOFEED1
$write 'q_out' queue_line,"-"
$queue_line="   "
$Q_NOFEED1:queue_line=queue_line + "/DEFAULT=(NOFEED)"
$Q_NOFEED2:if f$le(queue_line) + f$le(queue_name).le.77 then goto Q_E1B
$write 'q_out' queue_line,"-"
$queue_line="    "
$Q_E1B:write 'q_out' queue_line," ",queue_name
$if f$ex(0,ace_blank_cnt+12,record).nes.ace_blanks+"(IDENTIFIER=" then goto Q_END_2
$queue_acl=f$ed(record,"COLLAPSE")
$Q_1D_LOOP:read/end=Q_1D_1 queue record
$list_record=list_record + 1
$if record.eqs."" then goto Q_1D_1
$if f$ex(0,ace_blank_cnt+12,record).nes.ace_blanks+"(IDENTIFIER=" then goto SHOW_ERROR
$queue_acl=queue_acl + f$ed(record,"COLLAPSE")
$goto Q_1D_LOOP
$Q_1D_1:i=1
$acl_line="$SET ACL/OBJECT_TYPE=QUEUE/NEW/ACL=("
$delimiter="("
$Q_LOOP_1D_1:ace=f$ed(f$el(i,"(",queue_acl),"TRIM")
$if ace.eqs."(" then goto Q_END_1D
$i=i + 1
$a_len=f$le(ace)
$if (acl_line.eqs."   ").or.(f$le(acl_line) + f$le(delimiter) + a_len.le.77) then goto Q_1D_1_ADD_QUAL
$write 'q_out' acl_line,"-"
$acl_line="   "
$Q_1D_1_ADD_QUAL:acl_line=acl_line + delimiter + ace
$delimiter=",("
$goto Q_LOOP_1D_1
$Q_END_1D:if f$le(acl_line) + 1.le.77 then goto Q_E1D1
$write 'q_out' acl_line,"-"
$acl_line="    "
$Q_E1D1:acl_line=acl_line + ")"
$if f$le(acl_line) + f$le(queue_name).le.77 then goto Q_E1D2
$write 'q_out' acl_line,"-"
$acl_line="    "
$Q_E1D2:write 'q_out' acl_line," ",queue_name
$Q_END_2:if logical_queue.eqs."" then goto Q_E2_1
$write start "$WRITE SYS$OUTPUT ""Assigning logical queue ",queue_name," to ",logical_queue,""""
$write start "$ASSIGN/QUEUE ",logical_queue," ",queue_name
$Q_E2_1:comment=""
$if queue_start.nes."/START" then comment="!"
$write start "$"+comment+"WRITE SYS$OUTPUT ""Starting queue ",queue_name,""""
$write start "$"+comment+"START/QUEUE ",queue_name
$read/end=Q_EOF queue record
$list_record=list_record + 1
$if f$ex(0,1,record).nes." " then goto Q_LOOP_1
$if f$ex(0,job_hdr_len,record).nes.job_hdr then goto SHOW_ERROR
$read/end=SHOW_ERROR queue record
$list_record=list_record + 1
$if f$ex(0,job_hdr2_len,record).nes.job_hdr2 then goto SHOW_ERROR
$parsing_job="TRUE"
$batch_queue="FALSE"
$if f$loc("BATCH",queue_type).ne.qt_len then batch_queue="TRUE"
$print_submit="PRINT"
$if batch_queue then print_submit="SUBMIT"
$read/end=SHOW_ERROR queue record
$list_record=list_record + 1
$Q_LOOP_2:'if_v55 job_entry=f$ed(f$ex(1,6,record),"TRIM")
$'if_v55 if f$ty(job_entry).nes."INTEGER" then goto SHOW_ERROR
$'if_not_v55 job_name=f$ed(f$ex(2,15,record),"TRIM")
$'if_v55 job_name=f$ed(f$ex(9,15,record),"TRIM")
$if job_name.eqs."" then job_name=" "
$if f$ex(44,2,record).eqs."  " then goto Q_2_2LINE_1
$'if_not_v55 job_name=f$ex(2,f$le(record)-2,record)
$'if_v55 job_name=f$ex(9,f$le(record)-9,record)
$read/end=SHOW_ERROR queue record
$list_record=list_record + 1
$if f$ex(0,cont_blank_cnt,record).nes.cont_blanks then goto SHOW_ERROR
$Q_2_2LINE_1:if f$loc("/",job_name).ne.f$le(job_name) then goto SHOW_ERROR
$job_status=f$ex(46,999,record)
$'if_v4 if batch_queue then job_status=f$ex(38,999,record)
$'if_not_v55 job_user=f$ed(f$ex(18,12,record),"TRIM")
$'if_v55 job_user=f$ed(f$ex(25,12,record),"TRIM")
$'if_not_v55 job_entry=f$ed(f$ex(30,6,record),"TRIM")
$'if_not_v55 if f$ty(job_entry).nes."INTEGER" then goto SHOW_ERROR
$write sys$output "    Job ",job_name,", user ",job_user,", status ",f$ed(job_status,"COMPRESS")
$original_queue_name=queue_name
$job_line="$" + print_submit + "/NAME=""" + job_name + """"
$if f$ex(0,7,job_status).eqs."Pending" then goto Q_2_COPY
$if f$ex(0,14,job_status).eqs."Holding until " then goto Q_2_HOLD_UNTIL
$if f$ex(0,7,job_status).eqs."Holding" then goto Q_2_HOLD
$if f$ex(0,22,job_status).eqs."Retained on completion" then goto Q_2_SKIP
$if f$ex(0,9,job_status).eqs."Executing" then goto Q_2_HELD
$if f$ex(0,8,job_status).eqs."Printing" then goto Q_2_HELD
$if f$ex(0,17,job_status).eqs."Retained on error" then goto Q_2_RETAIN_ERR
$if f$ex(0,10,job_status).eqs."Processing" then goto Q_2_HELD
$if f$ex(0,8,job_status).eqs."Aborting" then goto Q_2_HELD
$if f$ex(0,8,job_status).eqs."Starting" then goto Q_2_HELD
$write sys$output "   Unrecognized job status"
$goto Q_2_HELD
$Q_2_RETAIN_ERR:read/end=SHOW_ERROR queue record
$list_record=list_record + 1
$if f$ex(0,error_blank_cnt,record).nes.error_blanks then goto SHOW_ERROR
$if f$ex(error_blank_cnt,1,record).nes."%" then goto SHOW_ERROR
$Q_2_HELD:write sys$output "    ...will be placed in queue with /HOLD"
$Q_2_HOLD:qualifier="HOLD"
$goto Q_2_1
$Q_2_HOLD_UNTIL:time=f$ed(f$ex(14,11,job_status),"TRIM") + ":" + f$ex(26,5,job_status)
$qualifier="AFTER=" + time
$Q_2_1:if f$le(job_line) + f$le(qualifier).le.77 then goto Q_2_3
$write jobs job_line,"-"
$job_line="   "
$Q_2_3:job_line=job_line + "/" + qualifier
$Q_2_COPY:qualifier="USER=" + job_user
$if f$le(job_line) + f$le(qualifier).le.77 then goto Q_2_0
$write jobs job_line,"-"
$job_line="   "
$Q_2_0:job_line=job_line + "/" + qualifier
$Q_3_0:read/end=Q_END_3 queue record
$list_record=list_record + 1
$if f$ex(0,error_blank_cnt+1,record).eqs.error_blanks+"-" then goto Q_3_0
$if f$ex(0,leading_blank_cnt,record).nes.leading_blanks then goto SHOW_ERROR
$if f$ex(leading_blank_cnt,9,record).nes."Submitted" then goto SHOW_ERROR
$rec_len=f$le(record)
$t=f$loc("/",record)
$if t.eq.rec_len then t=0
$job_qual=f$ed(f$ex(t,rec_len-t,record),"TRIM")
$Q_LOOP_3:read/end=Q_END_3 queue record
$list_record=list_record + 1
$if f$ex(0,leading_blank_cnt,record).nes.leading_blanks then goto SHOW_ERROR
$if f$ex(leading_blank_cnt,file_prefix_len,record).eqs.file_prefix then goto Q_END_3
$if f$ex(leading_blank_cnt,1,record).eqs." " then goto SHOW_ERROR
$job_qual=job_qual + f$ed(record,"TRIM")
$goto Q_LOOP_3
$Q_END_3:i=1
$Q_LOOP_3A:qualifier=f$ed(f$el(i,"/",job_qual),"TRIM")
$if qualifier.eqs."/" then goto Q_END_3A
$i=i + 1
$q_len=f$le(qualifier)
$if f$ex(0,8,qualifier).eqs."RESTART=" then goto Q_3A_RESTART
$t1=f$loc(" (stock=",qualifier)
$if t1.eq.q_len then goto Q_3A_QUAL_CHKD
$t2=f$loc(")",qualifier) + 1
$qualifier=f$ex(0,t1,qualifier) + f$ex(t2,(q_len-t2),qualifier)
$goto Q_3A_QUAL_CHKD
$Q_3A_RESTART:original_queue_name=qualifier - "RESTART="
$qualifier="RESTART"
$if original_queue_name.eqs."" then original_queue_name=queue_name
$if original_queue_name.eqs.queue_name then goto Q_3A_QUAL_CHKD
$write sys$output "    ...has /RESTART=''original_queue_name' and will be entered"
$write sys$output "       back into that queue instead of ''queue_name'"
$Q_3A_QUAL_CHKD:if (job_line.eqs."   ").or.(f$le(job_line) + q_len.le.77) then goto Q_3A_ADD_QUAL
$write jobs job_line,"-"
$job_line="   "
$Q_3A_ADD_QUAL:job_line=job_line + "/" + qualifier
$goto Q_LOOP_3A
$Q_END_3A:qualifier="QUEUE=" + original_queue_name
$if f$le(job_line) + f$le(qualifier).le.77 then goto Q_3A1
$write jobs job_line,"-"
$job_line="   "
$Q_3A1:job_line=job_line + "/" + qualifier
$write jobs job_line," -"
$if f$ex(0,leading_blank_cnt,record).nes.leading_blanks then goto SHOW_ERROR
$if f$ex(leading_blank_cnt,file_prefix_len,record).nes.file_prefix then goto SHOW_ERROR
$Q_LOOP_4:file_line="     " + f$el(0," ",f$ed(record,"TRIM") - "File: ")
$if f$loc("[]",file_line).eq.f$le(file_line) then goto Q_CONT_4A
$write sys$output "    ...''print_submit' command will fail; file not in directory:"
$write sys$output " ",file_line
$not_in_dir="TRUE"
$goto Q_CONT_4A
$Q_LOOP_4A:read/end=Q_END_4 queue record
$list_record=list_record + 1
$if f$ex(0,leading_blank_cnt,record).nes.leading_blanks then goto Q_END_4AR
$if f$ex(leading_blank_cnt,1,record).eqs." " then goto Q_END_4AR
$Q_CONT_4A:i=1
$Q_LOOP_4B:qualifier=f$ed(f$el(i,"/",record),"TRIM")
$if qualifier.eqs."/" then goto Q_LOOP_4A
$i=i + 1
$if (file_line.eqs."   ").or.(f$le(file_line) + f$le(qualifier).le.77) then goto Q_4B_ADD_QUAL
$write jobs file_line,"-"
$file_line="   "
$Q_4B_ADD_QUAL:file_line=file_line + "/" + qualifier
$goto Q_LOOP_4A
$Q_END_4AR:if f$ex(0,leading_blank_cnt,record).nes.leading_blanks then goto Q_END_4AR_1
$if f$ex(leading_blank_cnt,file_prefix_len,record).eqs.file_prefix then goto Q_4_NXTFIL
$Q_END_4AR_1:write jobs file_line
$if record.nes."" then goto SHOW_ERROR
$read/end=SHOW_ERROR queue record
$list_record=list_record + 1
$if f$ex(0,1,record).nes." " then goto Q_LOOP_1
$goto Q_LOOP_2
$Q_4_NXTFIL:write jobs file_line,",-"
$goto Q_LOOP_4
$Q_2_SKIP:write sys$output "    ...will be dropped."
$Q_2_SKIP_1:read/end=Q_EOF queue record
$list_record=list_record + 1
$if record.eqs."" then goto Q_2_SKIP_LOOP
$if f$ex(0,leading_blank_cnt,record).eqs.leading_blanks then goto Q_2_SKIP_LOOP
$if f$ex(0,1,record).nes." " then goto Q_LOOP_1
$goto Q_LOOP_2
$Q_2_SKIP_LOOP:goto Q_2_SKIP_1
$Q_END_4:write jobs file_line
$Q_EOF:close queue
$write sys$output "Parsing done."
$close com
$write generic "$DONE_QUEUES:"
$close generic
$append FIXQUE_QUEUE_GENERIC.TEMP FIXQUE_RELOAD.COM
$write jobs "$DONE_JOBS:"
$write jobs "$ASK_START:"
$write jobs "$INQUIRE ANS ""Do you wish to start queues and assign logical queues? [Y]"""
$write jobs "$ANS=F$EXTRACT(0,1,F$EDIT(ANS,""TRIM,UPCASE""))"
$write jobs "$IF ANS .EQS. ""N"" THEN GOTO DONE_START"
$write jobs "$IF ANS .NES. """" .AND. ANS .NES. ""Y"" THEN GOTO ASK_START"
$write sys$output "Generating START/QUEUE commands"
$close jobs
$append FIXQUE_QUEUE_JOBS.TEMP FIXQUE_RELOAD.COM
$write start "$DONE_START:"
$write start "$WRITE SYS$OUTPUT ""FIXQUE_RELOAD done."""
$close start
$append FIXQUE_QUEUE_START.TEMP FIXQUE_RELOAD.COM
$if.not.rerun then delete/nolog FIXQUE_QUEUE_GENERIC.TEMP;*,FIXQUE_QUEUE_JOBS.TEMP;*,FIXQUE_QUEUE_START.TEMP;*
$Q_DONE:
$CLEANUP:close/nolog chars
$close/nolog forms
$close/nolog queue
$close/nolog generic
$close/nolog jobs
$close/nolog start
$close/nolog com
$if.not.got_error then goto CLEANUP_1
$write sys$output "***"
$write sys$output "*** Parsing errors were encountered.  The output command procedure"
$write sys$output "*** FIXQUE_RELOAD.COM is incomplete and will need manual editing."
$write sys$output "***"
$CLEANUP_1:if.not.not_in_dir then goto CLEANUP_2
$write sys$output "***"
$write sys$output "*** Job(s) were found which contain files which are not entered in a"
$write sys$output "*** directory.  These could be files created by copying to a spooled"
$write sys$output "*** device.  A job containing such a file cannot be requeued through DCL."
$write sys$output "*** Note: The workaround is to do an ANALYZE/DISK/REPAIR on the"
$write sys$output "***       disk(s) involved to place all such files into the [SYSLOST]"
$write sys$output "***       directory.  Then this procedure must be run again."
$write sys$output "***"
$CLEANUP_2:write sys$output "FIXQUE done."
$write sys$output "Check FIXQUE_RELOAD.COM for accuracy before use."
$if.not.rerun then purge/nolog fixque_CHARS.list
$if.not.rerun then purge/nolog fixque_FORMS.list
$if.not.rerun then purge/nolog fixque_QUEUE.list
$if.not.rerun then purge/nolog FIXQUE_RELOAD.COM
$if old_priv.nes."" then old_priv=f$set(old_priv)
$exit
$SHOW_ERROR:got_error="TRUE"
$write sys$output "FIXQUE encountered an error in parsing"
$write sys$output "   input file ",list_file
$write sys$output "   at line ",list_record,", which contained:"
$write sys$output "   """,record,""""
$if list_file.eqs."FIXQUE_QUEUE.LIST" then goto SE_Q
$write com "$WRITE SYS$OUTPUT ","""An error in parsing was encountered by FIXQUE.COM at this point..."""
$if list_file.eqs."FIXQUE_CHARS.LIST" then goto C_LOOP_1
$SF_SKIP:if record.eqs."" then goto F_LOOP_1
$SF_SKIP_LOOP:read/end=F_EOF forms record
$list_record=list_record + 1
$if record.eqs."" then goto F_LOOP_1
$if f$ex(0,1,record).nes." " then goto F_CONT_1
$goto SF_SKIP_LOOP
$SE_Q:t=q_out
$if parsing_job then t="jobs"
$write 't' "$WRITE SYS$OUTPUT ","""An error in parsing was encountered by FIXQUE.COM at this point..."""
$if parsing_job then goto Q_2_SKIP_1
$SE_SKIP:read/end=Q_EOF queue record
$list_record=list_record + 1
$if record.eqs."" then goto SE_SKIP_LOOP
$if f$ex(0,1,record).nes." " then goto Q_LOOP_1
$SE_SKIP_LOOP:goto SE_SKIP

Mark D. Jilson
OpenVMS Internals Drivers & Performance
Colorado Customer Support Center
Compaq Services
Compaq Computer Corporation
