void put_integer ( int x ) {
	if ( x < 0 ) {
		put_char ( 45 ) ;
		x = 0 - x ;
	}	
	if ( x / 10 ) {
		put_integer ( x / 10 ) ;
	}
	int y = x % 10 ;
	put_char ( y + 48 ) ;
}

int fib ( int x ) {
	if ( x == 0 ) {
		return 1 ;
	}

	if ( x == 1 ) {
		return 1 ;
	}

	return fib ( x - 1 ) + fib ( x - 2 ) ;
}


int main ( ) {
	put_integer ( fib ( 6 ) ) ;
	put_char ( 10 ) ;
	return 0 ;
}
