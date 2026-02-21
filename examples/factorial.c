void put_integer ( int x ) {
	if ( x < 0 ) {
		put_char ( 45 ) ;
		x = 0 - x ;
	}	
	if ( x / 10 ) {
		put_integer ( x / 10 ) ;
	}
	x = x % 10 ;
	put_char ( x + 48 ) ;
}


int factorial ( int v ) {
	if ( v == 0 ) { 
		return 1 ;
	}
	return 	factorial ( v - 1 ) * v ;
}

int main ( ) { 
	put_integer ( factorial ( 5 ) ) ;
	put_char ( 10 ) ;
}
