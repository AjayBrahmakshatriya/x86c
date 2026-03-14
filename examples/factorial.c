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
	int y = x % 10 ;
	put_char ( y + 48 ) ;
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
