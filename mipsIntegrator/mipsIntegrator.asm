
.data
N: .word 100
a: .float 0
b: .float 1
error: .asciiz "error: must have low < hi\n"

.text 
###########################################################
main:
	# set argument registers appropriately
	la $t0,a		#load address of a into $t0
	lwc1 $f12,0($t0)	#load a into f12 from address in t0
	
	la $t0,b
	lwc1 $f13,0($t0)	#load b into f13
	
	
	
	la $a0,ident		#put the address of func in a0
	# call integrate on test function 
	jal integrate
	# print result and exit with status 0
	li $v0,2
	mov.s $f12,$f0		#return value in $f0 put in $f12
	syscall			#print result
	
	li $v0,17
	add $a0,$zero,$zero
	syscall
	

###########################################################
# float integrate(float (*func)(float x), float low, float hi)
# integrates func over [low, hi]
# $f12 gets low, $f13 gets hi, $a0 gets address (label) of func
# $f0 gets return value
integrate: 
	addi $sp,$sp,-4		#make space for ra on stack
	sw $ra,0($sp)		#save ra on stack
	jal check
	
	lw $ra,0($sp)		#get back ra to go back to main
	addi $sp,$sp,4		#pop stack
	
	# initialize $f4 to hold N
	# since N is declared as a word, will need to convert
	la $t0,N
	lwc1 $f4,0($t0)		#load word at N into $f4
	cvt.s.w $f4,$f4		#convert word to float and store in $f4
	
	sub.s $f0,$f13,$f12	#b-a
	div.s $f1,$f0,$f4	#(a-b)/n --> $f1 contains delta x
	
	addi $t0,$zero,1	#start at i=1
	mtc1 $t0,$f2		#$f2 contains i
	cvt.s.w $f2,$f2
	
	add $t0,$zero,$zero	#initialize sum variable
	mtc1 $t0,$f9		#$f9 contains sum
	cvt.s.w $f9,$f9
	
loop:	c.eq.s $f2,$f4		#want this to be true once i=N
	
	#find x_subi_* (midpoint)
	#1. find i*deltax
	mul.s $f20,$f2,$f1	#$f2 = i;$f1 = deltax
	
	#2. a+i*deltax = x_sub_i
	add.s $f21,$f12,$f20	#$f12 = a; $f20 = i*deltax; f$21 = x_sub_i
	
	#3. find (i-1)
	mov.s $f22,$f2		#$f22 = copy of i
	addi $t0,$zero,1	#make t0 = 1
	mtc1 $t0,$f23		#$f23 = 1
	cvt.s.w $f23,$f23
	sub.s $f24,$f22,$f23	#i-1 = $f24
	
	#4. find (i-1)*deltax
	mul.s $f20,$f24,$f1	#(i-1)*deltax = $f20
	
	#5. find a+(i-1)*deltax
	add.s $f25,$f12,$f20	#a+(i-1)*deltax = $f25 = x_sub_i-1
	
	#6. find x_sub_i_* by doing (x_sub_i+x_sub_i-1)/2 (find midpoint)
	add.s $f26,$f25,$f21	#x_sub_i+x_sub_i-1=$f26
	addi $t0,$zero,2
	mtc1 $t0,$f23		#$f23 = 2
	cvt.s.w $f23,$f23
	div.s $f7,$f26,$f23	#f7 = x_sub_i_* (midpoint)
	
	#find f(x_sub_i_*)
	addi $sp,$sp,-8
	swc1 $f12,0($sp)
	sw $ra,4($sp)		#save both f12 = a and ra because func will take as input f12 and will update ra
	mov.s $f12,$f7		#send midpoint as argument
	jalr $a0		#go to label of function, return value in $f0
	
	lwc1 $f12,0($sp)	#get back f12 = a
	lw $ra,4($sp)		#get back ra
	addi $sp,$sp,8		#pop stack
	
	mul.s $f10,$f0,$f1	#f(x_sub_i_*)*deltax = $f10
	add.s $f9,$f9,$f10	#sum+$f10
	
	bc1t finIntegrate	#if previous operation was at i=N exit
	
	#if not i=N
	addi $t0,$zero,1
	mtc1 $t0,$f11		#$f11 = 1
	cvt.s.w $f11,$f11
	add.s $f2,$f2,$f11	#$f2 = i+1 --> increment	
	j loop			#do next iteration
	
finIntegrate:
	mov.s $f0,$f9		#move sum into $f0
	jr $ra

###########################################################
# void check(float low, float hi)
# checks that low < hi
# $f12 gets low, $f13 gets hi
# # prints error message and exits with status 1 on fail
check:
	c.lt.s $f12,$f13
	
	bc1f exitError		#if f12 is not <f13, code will be false and we exitError
	
	jr $ra			#if not then we go back to integrate function

exitError:
	addi $sp,$sp,4		#pop stack
	
	li $v0,4		#print error message
	la $a0,error
	syscall
	
	li $v0,17		#exit with status 1
	addi $a0,$zero,1
	syscall

###########################################################
# float ident(float x) { return x; }
# function to test your integrator
# $f12 gets x, $f0 gets return value
ident:
	mov.s $f0, $f12
	jr $ra
