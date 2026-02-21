int factorial ( int v ) {
	if ( v == 0 ) { 
		return 1 ;
	}
	return 	factorial ( v - 1 ) * v ;
}

int main ( ) { 
	return factorial ( 5 ) ;
}
