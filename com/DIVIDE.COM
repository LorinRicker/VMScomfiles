$! DIVIDE.COM
$!
$ ! Copyright © 1999-2016 by Lorin Ricker.  All rights reserved, with acceptance,
$ ! use, modification and/or distribution permissions as granted and controlled
$ ! by and under the GPL described herein.
$ !
$ ! This program (software) is Free Software, licensed under the terms and
$ ! conditions of the GNU General Public License Version 3 as published by
$ ! the Free Software Foundation: http://www.gnu.org/copyleft/gpl.txt,
$ ! which is hereby incorporated into this software and is a non-severable
$ ! part thereof.  You have specific rights and obligations under this GPL
$ ! which are binding if and when you accept, use, modify and/or distribute
$ ! this software program (source code file) and/or derivatives thereof.
$ !
$!   P1 -  Dividend.
$!   P2 -  Divisor.
$!   P3 -  the number of decimal places to carry out div.  (Default to 2)
$!
$! Example of use:
$!    Syntax                    Result
$!   ---------------------      -------------------------------
$!   @divide 4596.84 3.76 4     returns: divide_ans = 1222.5638
$!   @divide 4596.84 3.76 3     returns: divide_ans = 1222.564
$!   @divide 4596.84 3.76 2     returns: divide_ans = 1222.56
$!      (Note: Rounding to 2 places is automatic_)
$!
$!
$! Initialize variables
$ Divide_ans  == ""          ! Quotient answer as a string with decimal
$ GOSUB Set_Divisor          ! passed in as P2
$ GOSUB Set_Dividend         ! passed in as P1
$ IF P3 .EQS. "" THEN P3 = 2 ! Default num of decimals to 2, already in decimals
$ final_decimal =  f$length(before_dec1) + f$length(after_dec2)
$ Num_of_Divides = final_decimal + (P3 +1)  ! Determines the number of iterations to perform.
$                                           ! (do one more than requested for proper rounding.)
$! "long division" Loop
$ Cnt = 0                                 ! initialize counter
$ Build_Final = ""                        ! initialize string
$ New_dividend = f$extract(0,1,Dividend)  ! Start trying to divide first digit
$Calc_Answer:
$ Cnt  = Cnt + 1
$ IF Cnt .GT. Num_of_divides .OR. Cnt .EQ. 50 THEN GOTO End_Calc_Answer        ! Limit loop max = 50, just for safety.
$ quotient = New_dividend / Divisor    
$ IF quotient .EQ. 0  .AND. Build_Final .EQS. ""
$ THEN ! Toss out heading zero's.  (This will allow us to divide much bigger numbers.)
$ ELSE Build_Final = Build_Final + f$string(quotient)  ! Save the integer result of the division...
$ ENDIF
$ GOSUB Calc_new_dividend
$ GOTO Calc_Answer
$End_Calc_Answer:
$!
$ GOSUB Do_Rounding
$ SHOW SYMBOL divide_ans
$!
$Normal_exit:
$ EXIT
$!
$! Subroutines
$SET_DIVISOR:
$ after_dec2  = ""                                            ! No decimal assumed until proven otherwise.
$ decimal_pt2 = f$locate(".",P2)                              ! See if there is a decimal in the divisor.
$ if decimal_pt2 .EQ. f$length(P2)
$ then
$      ! No decimal in Divisor.  (that is, it is all integers).
$      divisor = P2
$      decimal_pt2 = 0
$ else
$      ! Strip decimal from divisor.  We know how many places there were (decimal_pt2)
$      before_dec2  = f$extract(0,decimal_pt2,P2)
$      after_dec2   = f$extract(decimal_pt2+1,99,P2)
$      divisor     = f$string(before_dec2) + f$string(after_dec2)
$ endif
$ RETURN
$!
$!
$SET_DIVIDEND:
$ after_dec1 = ""                 ! No decimal assumed until proven otherwise
$ before_dec1 = ""
$ decimal_pt1 = f$locate(".",P1)  ! See if a number with a decimal was entered
$ IF decimal_pt1 .EQ. f$length(P1)
$ THEN ! No decimal in P1
$      dividend = P1
$      before_dec1 = P1
$ ELSE ! Split number...(125.59, into 125 and 59)
$      before_dec1  = f$extract(0,decimal_pt1,P1)
$      after_dec1   = f$extract(decimal_pt1+1,2,P1)
$      dividend     = f$string(before_dec1) + f$string(after_dec1)
$ ENDIF
$ RETURN
$!
$CALC_NEW_DIVIDEND:
$ !New dividend is always remainder with next digit or *10
$ New_dividend = (New_dividend - (quotient * divisor)) * 10
$ ! Determine if dividend is okay as stands, or needs next digit in number...
$ IF cnt .LT. f$length(dividend)
$ THEN ! We haven't used up all the digits in the original number.
$      ! Add next digit to the new dividend
$      New_dividend = New_dividend + f$extract(cnt,1,dividend)
$ !ELSE ! We've used all the numbers in the original number.
$ ENDIF
$ RETURN
$!
$DO_ROUNDING:
$! Handle rounding and save answer to global symbol "divide_ans"
$ last_dig = f$extract(f$length(build_final)-1,1,build_final)
$ rounded  = f$extract(0,f$length(build_final)-1,build_final)  !Get rid of last digit
$ IF last_dig .GE. 5
$ THEN rounded = rounded + 1    ! round up
$ !ELSE                         ! no rounding needed
$ ENDIF
$!
$ divide_ans == f$extract(0,f$length(rounded)-P3,rounded) -
              + "." + f$extract(f$length(rounded)-P3,P3,rounded)
$ Return
$!
$Error_Exit:
$ EXIT
