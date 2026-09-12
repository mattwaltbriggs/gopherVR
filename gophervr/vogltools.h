
void RotateAboutAxis(float val);

void EyeAirJordan(void (*displayfunc)(), float lookDownAmount, float Moveahead,
		  float Moveup, float seconds);

void EyeInitialPoint( void );
void JumpOutofView(void (*displayfunc)());
void JumpIntoView(void (*displayfunc)());
void MotionSickness(void (*displayfunc)());
void makegroundplane(void);
void drawscene(void);
void EyeLocationUp(int);
