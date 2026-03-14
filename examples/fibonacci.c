void put_char ( int x ) {
	syscall6 ( 1 , 1 , & x , 1 , 0 , 0 , 0 ) ;
} 

void put_integer ( int x ) {
	if ( x < 0 ) {
		put_char ( 45 ) ;
		x = 0 - x ;
	}	
	if ( x / 10 ) {
		put_integer ( x / 10 ) ;
	}
	put_char ( x % 10 + 48 ) ;
}

long fib ( long x ) {
	if ( x == 0 || x == 1 ) {
		return 1 ;
	}
	return fib ( x - 1 ) + fib ( x - 2 ) ;
}


int main ( ) {
	put_integer ( fib ( 43 ) ) ;
	put_char ( 10 ) ;
	return 0 ;
}
