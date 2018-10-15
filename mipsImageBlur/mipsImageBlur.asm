
.data

#Change the str1 file directory to full path containing the test image
str1:	.asciiz "C:\\Users\\obiaf\\Documents\\McGill\\2017-2018\\Fall 2017\\COMP 273\\Assignments\\Assignment 4\\Assignment4\\test1.txt"
str3:	.asciiz "test-blur.pgm"	#used as output
errormsg1: .asciiz "File could not be opened."
errormsg2: .asciiz "File could not be read."
errormsg3: .asciiz "File could not be written to."
header: .asciiz "P2\n24 7\n15\n"

buffer:  .space 2048		# buffer for upto 2048 bytes
newbuff: .space 2048
tmpbuff: .align 2		#was not aligning properly so had to add this for me to be able to access words
	 .space 800		#buffer to store int values of buffer before blur
avgbuff: .align 2		#buffer to store the average values
	 .space 800
convbuff:.space 5		#numbers probly won't be more than 5 bytes when turned into char

	.text
	.globl main

main:	la $a0,str1		#readfile takes $a0 as input
	jal readfile

	la $a1,buffer		#$a1 will specify the "2D array" we will be averaging
	la $a2,newbuff		#$a2 will specify the blurred 2D array.
	jal blur

	
	la $a0, str3		#writefile will take $a0 as file location
	add $a1,$v1,$zero	#put blurred array into a1
	jal writefile

	li $v0,10		# exit
	syscall

readfile:
#Open the file to be read,using $a0
#Conduct error check, to see if file exists
	li $v0,13		#syscall to open file
	li $a1,0
	syscall
	
	slt $t0,$v0,$zero	#if return value from previous syscall is negative, we not good so error proced 
	bne $zero,$t0,nofile
	

# You will want to keep track of the file descriptor*
	add $t0,$zero,$v0	#we put in the file descriptor in t0
	
# read from file
# use correct file descriptor, and point to buffer
# hardcode maximum number of chars to read
	li $v0,14
	add $a0,$t0,$zero	#put file descriptor from t0 into a0
	la $a1,buffer		#load buffer into a1
	addi $a2,$zero,2048	#max chars to read
	syscall 
# read from file
	slt $t2,$v0,$zero #if return value from previous syscall is negative, something went wrong
	bne $t2,$zero,noread	#if there was an error print out a message and exit
	
	
# address of the ascii string you just read is returned in $v1.
	add $v1,$zero,$a1	#$a1 contains address to buffer
	
# the text of the string is in buffer
# close the file (make sure to check for errors)
	li $v0,16
	add $a0,$zero,$t0	#$t0 contains file descripter
	syscall
	
	jr $ra


blur:
#use real values for averaging.
#HINT set of 8 "edge" cases.
#The rest of the averaged pixels will 
#default to the 3x3 averaging method
#we will return the address of our
#blurred 2D array in #v1

#we will not be doing anything to rows 1 and 7, as well as columns 1 and 24
#we need to go through rows 2-6, and for each row get every column 2-23 and get averages
#there are also two spaces between every character horizontally, so we need to take that into account
	
	add $sp,$sp,-12			#make space for two words on stack
	sw $a1,0($sp)
	sw $a2,4($sp)			#save arguments onto stack
	sw $ra,8($sp)
	
	addi $t0,$zero,32 		#ascii value of space
	la $t1,tmpbuff			#load address of tmp buffer
	add $t2,$zero,$zero		#initialize register that will store int values
	addi $t4,$zero,10		#ascii value of new line
	add $t5,$zero,$zero		#number of rows done
	#go through buffer and write ascii chars as ints into a tmp array
writeTmp:
	add $t2,$zero,$zero		#reinitialize register storing int values
	
loop:	
	slti $t6,$t5,7
	beq $t6,$zero,avg		#once we have written 7 lines, $t6 becomes 0 so we finish
	lb $t3,0($a1)			#load byte from buffer
	beq $t3,$t0,next		#if it is a space, restart
	beq $t3,$t4,nextLine		#if it is a newline
	
	mul $t2,$t2,10			#multiply by 10
	subi $t3,$t3,48			#48 -->0 digit
	add $t2,$t3,$t2			#add to whatever number we were building
	addi $a1,$a1,1			#go to next byte
	j loop 
	
next:
	sw $t2,0($t1)			#save int in buffer since we've hit a space
skip:	addi $a1,$a1,1			#go past one space in buffer
	lb $t3,0($a1)			#query next char
	beq $t3,$t0,skip		#if space again, we have to skip this one
	addi $t1,$t1,4			#increment tmp buffer if not, and then write next chars
	
	j writeTmp
nextLine:
	sw $t2,0($t1)			#save int in buffer since we have to last char of the line in $t2
	addi $t1,$t1,4			#go to next slot in tmp buffer
	addi $a1,$a1,1			#point to start of next line
	addi $t5,$t5,1			#update number of rows we did
	j writeTmp
	#databuff has all the right values, I checked
	
avg:	#once we get here we've finished writing the tmp buffer and have all values
	#now we will put average values into a avgbuffer that will contain all the averaged values
	
	add $t0,$zero,$zero		#initialize rows i to 0
	add $t1,$zero,$zero		#initialize columns j to 0
	la $t2,tmpbuff			#reload address of tmpbuff
	la $t3,avgbuff			#load address of avgbuff, where we will store the average values
	
cases:	#if i=0, j=0, i=6, j=23, we dont want to average, simply put these in

	beq $t0,$zero,edgecase1		#if i=0 put in all the values of that row and go to next row
	slti $t4,$t0,6
	beq $t4,$zero,edgecase4		#if i=6, it is the last row, so put in all the ints and once
					#your're at 24, exit the averaging 		
	beq $t1,$zero,edgecase2		#if j=0 put in the value of that cell and go to next cell
	slti $t4,$t1,23			#if j=23, we have to put in the last int then go to next line
	beq $t4,$zero,edgecase3
	
	
	
	#if we here, then not edgecase			
	
	#this is the order in which we will be accessing each of the 3x3 values
	
	#                    6 5 4		1 being the first and 9 being last to be added to sum
	#		     2 1 3
	#		     7 8 9	
	#we then make sure pointer of tmpbuff points to 1
	
	#1.
	lw $t4,0($t2)			#load int from tmpbuff into $t4, which is going to be the sum register
	
	#2.
	addi $t2,$t2,-4			#we need to add or substract by blocks of 4 because ints are stored as words
	lw $t5,0($t2)			#get int
	add $t4,$t4,$t5			#add to sum
	
	#3.
	addi $t2,$t2,8			
	lw $t5,0($t2)			#get int
	add $t4,$t4,$t5			#add to sum
	
	#4.
	addi $t2,$t2,-96
	lw $t5,0($t2)
	add $t4,$t4,$t5
	
	#5.
	addi $t2,$t2,-4
	lw $t5,0($t2)
	add $t4,$t4,$t5
	
	#6.
	addi $t2,$t2,-4
	lw $t5,0($t2)
	add $t4,$t4,$t5
	
	#7.
	addi $t2,$t2,192		#jump two rows
	lw $t5,0($t2)
	add $t4,$t4,$t5
	
	#8.
	addi $t2,$t2,4
	lw $t5,0($t2)
	add $t4,$t4,$t5
	
	#9.
	addi $t2,$t2,4
	lw $t5,0($t2)
	add $t4,$t4,$t5
	
	#go back to point to cell 1
	addi $t2,$t2,-100
	
	div $t4,$t4,9			#average = sum/9
	
	sw $t4,0($t3)			#save average in appropriate slot of avgbuffer
	addi $t1,$t1,1			#increment column j
	addi $t2,$t2,4			#go to next int in tmpbuff
	addi $t3,$t3,4			#prepare to write to next slot in avgbuff
	j cases				#go back to check cases
	
edgecase1: #we are at the first row, so we keep adding to avgbuffer until we put in j=23
	slti $t5,$t1,24
	beq $zero,$t5,newrow		#once we put in 24th int, we go to next line
	lw $t4,0($t2)			#load int from tmpbuffer into $t4
	sw $t4,0($t3)			#store int in avgbuffer
	addi $t2,$t2,4
	addi $t3,$t3,4			#incr both pointers
	addi $t1,$t1,1			#increment column
	j edgecase1			#go to next column

edgecase2: #j=0, so we add the int and then incr
	lw $t4,0($t2)			#load int from tmpbuffer into $t4
	sw $t4,0($t3)			#save int into avgbuffer
	addi $t2,$t2,4
	addi $t3,$t3,4			#incr both pointers
	addi $t1,$t1,1			#j++
	j cases				#check for cases again
	
edgecase3: #writing to slot j=23, so we just add the int in tmpbuffer and go to next line
	lw $t4,0($t2)			#load in from tmpbuff
	sw $t4,0($t3)			#store int in avgbuff
	addi $t2,$t2,4
	addi $t3,$t3,4
	j newrow				#go to next line

edgecase4: #we're at the last row, so we add all ints on that row and then finish avg
	slti $t5,$t1,24			#as long as j<24
	beq $t5,$zero,blurthebuff	#once we've finished writing all the ints, we move on to the next step
	lw $t4,0($t2)
	sw $t4,0($t3)			#load from tmpbuff and store in avgbuff
	addi $t2,$t2,4
	addi $t3,$t3,4			#incr pointers
	addi $t1,$t1,1			#j++
	j edgecase4
  
newrow:	
	add $t1,$zero,$zero		#reinitialize col j
	addi $t0,$t0,1			#incr rows
	j cases				#go back to check cases

blurthebuff:	#once we get here, we have all of our averaged values in the buffer: CHECKED THIS AS WELL
	
	#now we write to the blurred 2d array newbuff in $a2
	lw $t4,4($sp)			#$t4 contains head of newbuff
	la $t2,avgbuff
	add $t3,$zero,$zero		#initialize counter to count how many ints put in
	
	
	
writeBlur:
	addi $t0,$zero,24		#num of columns in total
	slti $t5,$t3,168		#need to write 168 ints to newbuff
	beq $t5,$zero,finish
	div $t3,$t0			#divide number of ints with 24 to know which column wer're at
	mfhi $t1			#$t1 is the column we're at
	#convert int to ascii
	add $a1,$t2,$zero		#put address of int we want to convert into $a1
	la $a2,convbuff			#send address of buffer that will store the chars
	jal intToAscii			#do int to ascii, will return $v0=convbuff,$v1=number of chars
	
	beq $t1,$zero,linereturn	#if we're at the first column we must first add a new line
	
	bne $t1,$zero,checkspace	#unless it is the first entry of the row we must check if we need to add a space
	
nextChar:
	sle $t6,$v1,$zero		#set t6 if number of chars becomes less than or equal to 0
	bne $t6,$zero,nextInt		#if we have written all the chars representing current int, we go to next
	
	lb $t7,0($v0)
	sb $t7,0($t4)			#put char from convbuffer to newbuffer
	
	addi $t4,$t4,1			#point to next byte slot in newbuff
	subi $v1,$v1,1			#1 less char to write
	j nextChar			#check if we need to write next char

nextInt:
	addi $t2,$t2,4			#go to next int in avgbuffer
	addi $t3,$t3,1			#number of ints added++
	j writeBlur			#go write next int
	
checkspace:
	slti $t6,$v1,2			#if number can be written with less than 2 chars t6=1
	addi $t7,$zero,32	
	sb $t7,0($t4)	
	bne $t6,$zero,twospace		#add two spaces to newbuff
	#else only add one space
	addi $t4,$t4,1			#go to next byte slot in newbuff
	j nextChar			#go write next set of int to chars
twospace:
	sb $t7,1($t4)			#store second space
	addi $t4,$t4,2			#point to next available byte slot
	j nextChar

linereturn:
	addi $t7,$zero,10		#new line char
	sb $t7,0($t4)			#store in newbuff
	addi $t4,$t4,1			#go to next byte
	j nextChar			#write next char
	
finish:
	addi $t7,$zero,10		#newline char
	sb $t7,0($t4)			#store in newbuff
	lw $v1,4($sp)			#get back head of newbuff through stackpointer
	lw $ra,8($sp)
	addi $sp,$sp,12			#pop stack
	jr $ra
	

writefile:
	move $t3,$a1	#move buffer
#open file to be written to, using $a0.
	li $v0,13		#syscall to open file
	#a0 str3 -->file we want to write in
	li $a1,1	#flag 1
	syscall
	
	slt $t0,$v0,$zero	#if return value from previous syscall is negative, we not good so error proced 
	bne $zero,$t0,nofile
	
	add $t0,$zero,$v0	#store file descriptor
	

#P2
#24 7
#15
	#a1 contains label of buffer read
	add $t1,$zero,$a1
	li $v0,15		#syscall 15
	add $a0,$zero,$t0	#file descriptor
	la $a1,header		#write from header to file
	li $a2,11		#write 10 bytes
	syscall
	
	slt $t2,$v0,$zero	#if return value from previous syscall is negative, we not good so error proced 
	bne $zero,$t2,nowrite
#write the content stored at the address in $a1.
	add $a1,$zero,$t3	#move buffer back to a1
	
	li $v0,15		#syscall 15
	add $a0,$zero,$t0	#file descriptor
	#a1 already contains buffer
	li $a2,2037		#we already wrote 10 bytes, so max is now 2038
	syscall
	
	
	slt $t2,$v0,$zero	#if return value from previous syscall is negative, we not good so error proced 
	bne $zero,$t2,nowrite
	
#close the file (make sure to check for errors)
	li $v0,16
	#a0 already file descriptor
	syscall		#closes file
	jr $ra
	
#if file does not exist
nofile:
	li $v0,4		#print error message
	la $a0,errormsg1
	syscall
	
	li $v0,17		#return with error
	addi $a0,$zero,1
	syscall

noread:
	li $v0,4		#print error message
	la $a0,errormsg2	
	syscall
	
	li $v0,17		#return with error
	addi $a0,$zero,1
	syscall
	
nowrite:
	li $v0,4		#print error message
	la $a0,errormsg3	
	syscall
	
	li $v0,17		#return with error
	addi $a0,$zero,1
	syscall
	
#procedure that takes address pointing to an integer in $a1 and returns in $v0 a buffer specified by $a2 that contains the chars
#corresponding to the integer, and in $v1 the number of chars needed to represent that integer
intToAscii:
	
	addi $sp,$sp,-12	#make place for three items on stack
	sw $ra,0($sp)
	sw $a1,4($sp)
	sw $a2,8($sp)
	add $v1,$zero,$zero	#how many chars 
	
	lw $t0,0($a1)		#get int we want to convert into $t0
	addi $t5,$zero,10
	
nextDig:div $t0,$t5
	mfhi $t6		#has remainder/digit
	mflo $t0		#put quotient into $t0
	addi $t6,$t6,48		#turn digit into ascii value of it
	sb $t6,0($a2)		#store digit in the output buffer
	
	addi $a2,$a2,1		#point to next byte slot
	addi $v1,$v1,1		#incr num of chars
	beq $t0,$zero,reverse	#if the quotient is 0, it means the digits are all in the buffer
	j nextDig		#if not then get next digit
reverse:
	#the buffer is in reverse order, so we must rectify it before returning
	sub $t6,$a2,$v1		#$t6 points to first byte in buffer
	addi $a2,$a2,-1		#$a2 pointing to the last byte inputted into buffer
	addi $t0,$zero,1	
	beq $v1,$t0,fin		#if there was only one digit, we dont do nothing
	
	add $t5,$zero,$zero	#the number of chars reversed
swap:	
	slt $t7,$t5,$v1		#if chars swapped<num chars, continue, or else we've swapped the whole buffer
	beq $t7,$zero,fin
	lb $t0,0($t6)		#left byte
	lb $t7,0($a2)		#right byte
	sb $t0,0($a2)		
	sb $t7,0($t6)
	addi $t5,$t5,2		#we swapped two chars
	addi $t6,$t6,1
	addi $a2,$a2,-1		#increment both pointers in opposite directions
	j swap

fin:
	lw $ra,0($sp)
	lw $a1,4($sp)
	lw $a2,8($sp)
	add $v0,$a2,$zero	#return convbuffer
	add $sp,$sp,12		#popstack
	jr $ra
	
	
