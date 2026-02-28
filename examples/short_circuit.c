int sideeffect ( ) { 
	put_char ( 97 ) ;
	return 1 ;
}

int main ( ) { 
	return 1 || 1 && sideeffect ( ) && 0 || sideeffect ( ) ;
}
