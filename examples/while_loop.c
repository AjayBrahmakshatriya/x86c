int ret ;
int factorial ( int x ) {
	ret = 1 ;
	while ( x ) {
		ret = ret * x ;
		x = x - 1 ;
	}
	return ret ;
}

int main ( ) {
	return factorial ( 0 ) ;
}
