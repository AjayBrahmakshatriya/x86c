void put_char ( int x ) {
	syscall6 ( 1 , 1 , & x , 1 , 0 , 0 , 0 ) ;
} 
int main ( ) { 
        put_char ( 72 ) ;
        put_char ( 101 ) ;
        put_char ( 108 ) ;
        put_char ( 108 ) ;
        put_char ( 111 ) ;
        put_char ( 32 ) ;
        put_char ( 87 ) ;
        put_char ( 111 ) ;
        put_char ( 114 ) ;
        put_char ( 108 ) ;
        put_char ( 100 ) ;
        put_char ( 33 ) ;
        put_char ( 10 ) ;
	return 0 ;
}
