void put_char ( int x ) {
	syscall6 ( 1 , 1 , & x , 1 , 0 , 0 , 0 ) ;
} 
int sideeffect ( ) { 
	put_char ( 97 ) ;
	return 1 ;
}

int main ( ) { 
	return 1 || 1 && sideeffect ( ) && 0 || sideeffect ( ) ;
}
