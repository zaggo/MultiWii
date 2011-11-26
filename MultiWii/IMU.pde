
void computeIMU () {
  uint8_t axis;
  static int16_t gyroADCprevious[3] = {0,0,0};
  int16_t gyroADCp[3];
  int16_t gyroADCinter[3];
  static int16_t lastAccADC[3] = {0,0,0};
  static uint32_t timeInterleave = 0;
  static int16_t gyroYawSmooth = 0;

  //we separate the 2 situations because reading gyro values with a gyro only setup can be acchieved at a higher rate
  //gyro+nunchuk: we must wait for a quite high delay betwwen 2 reads to get both WM+ and Nunchuk data. It works with 3ms
  //gyro only: the delay to read 2 consecutive values can be reduced to only 0.65ms
  if (!ACC && nunchuk) {
    annexCode();
    while((micros()-timeInterleave)<INTERLEAVING_DELAY) ; //interleaving delay between 2 consecutive reads
    timeInterleave=micros();
    WMP_getRawADC();
    getEstimatedAttitude(); // computation time must last less than one interleaving delay
    #if BARO
      getEstimatedAltitude();
    #endif 
    while((micros()-timeInterleave)<INTERLEAVING_DELAY) ; //interleaving delay between 2 consecutive reads
    timeInterleave=micros();
    while(WMP_getRawADC() != 1) ; // For this interleaving reading, we must have a gyro update at this point (less delay)

    for (axis = 0; axis < 3; axis++) {
      // empirical, we take a weighted value of the current and the previous values
      // /4 is to average 4 values, note: overflow is not possible for WMP gyro here
      gyroData[axis] = (gyroADC[axis]*3+gyroADCprevious[axis]+2)/4;
      gyroADCprevious[axis] = gyroADC[axis];
    }
  } else {
    if (ACC) {
      ACC_getADC();
      getEstimatedAttitude();
      if (BARO) getEstimatedAltitude();
    }
    if (GYRO) Gyro_getADC(); else WMP_getRawADC();
    for (axis = 0; axis < 3; axis++)
      gyroADCp[axis] =  gyroADC[axis];
    timeInterleave=micros();
    annexCode();
    while((micros()-timeInterleave)<650) ; //empirical, interleaving delay between 2 consecutive reads
    if (GYRO) Gyro_getADC(); else WMP_getRawADC();
    for (axis = 0; axis < 3; axis++) {
      gyroADCinter[axis] =  gyroADC[axis]+gyroADCp[axis];
      // empirical, we take a weighted value of the current and the previous values
      gyroData[axis] = (gyroADCinter[axis]+gyroADCprevious[axis]+1)/3;
      gyroADCprevious[axis] = gyroADCinter[axis]/2;
      if (!ACC) accADC[axis]=0;
    }
  }
  #if defined(TRI)
    gyroData[YAW] = (gyroYawSmooth*2+gyroData[YAW]+1)/3;
    gyroYawSmooth = gyroData[YAW];
  #endif
}

#if defined(STAB_OLD_17)
/// OLD CODE from 1.7 ////
// ************************************
// simplified IMU based on Kalman Filter
// inspired from http://starlino.com/imu_guide.html
// and http://www.starlino.com/imu_kalman_arduino.html
// for angles under 25deg, we use an approximation to speed up the angle calculation
// magnetometer addition for small angles
// ************************************
void getEstimatedAttitude(){
  uint8_t axis;  
  float R, RGyro[3];                 //R obtained from last estimated value and gyro movement;
  static float REst[3] = {0,0,1} ;   // init acc in stable mode
  static float A[2];                 //angles between projection of R on XZ/YZ plane and Z axis (in Radian)
  float wGyro = 300;               // gyro weight/smooting factor
  float invW = 1.0/(1 + 300);
  float gyroFactor;
  static uint8_t small_angle=1;
  static uint16_t tPrevious;
  uint16_t tCurrent,deltaTime;
  float a[2], mag[2], cos_[2];

  tCurrent = micros();
  deltaTime = tCurrent-tPrevious;
  tPrevious = tCurrent;

  #if GYRO
    gyroFactor = deltaTime/300e6; //empirical
  #else
    gyroFactor = deltaTime/200e6; //empirical, depends on WMP on IDG datasheet, tied of deg/ms sensibility
  #endif
  
  for (axis=0;axis<2;axis++) a[axis] = gyroADC[axis]  * gyroFactor;
  for (axis=0;axis<3;axis++) accSmooth[axis] =(accSmooth[axis]*7+accADC[axis]+4)/8;
  
  if(accSmooth[YAW] > 0 ){ //we want to be sure we are not flying inverted  
    // a very nice trigonometric approximation: under 25deg, the error of this approximation is less than 1 deg:
    //   sin(x) =~= x =~= arcsin(x)
    //   angle_axis = arcsin(ACC_axis/ACC_1G) =~= ACC_axis/ACC_1G
    // the angle calculation is much more faster in this case
    if (accSmooth[ROLL]<acc_25deg && accSmooth[ROLL]>-acc_25deg && accSmooth[PITCH]<acc_25deg && accSmooth[PITCH]>-acc_25deg) {
      for (axis=0;axis<2;axis++) {
        A[axis] +=a[axis];
        A[axis] = ((float)accSmooth[axis]/acc_1G + A[axis]*wGyro)*invW; // =~= sin axis
        #if MAG
          cos_[axis] = 1-A[axis]*A[axis]/2; // cos(x) =~= 1-x^2/2
        #endif
      } 
      small_angle=1;
    } else {
      //magnitude vector size
      R = sqrt(square(accSmooth[ROLL]) + square(accSmooth[PITCH]) + square(accSmooth[YAW]));
      for (axis=0;axis<2;axis++) {
        if ( acc_1G*3/5 < R && R < acc_1G*7/5 && small_angle == 0 ) //if accel magnitude >1.4G or <0.6G => we neutralize the effect of accelerometers in the angle estimation
          A[axis] = atan2(REst[axis],REst[YAW]);
        A[axis] +=a[axis];
        cos_[axis] = cos(A[axis]);
        RGyro[axis]  = sin(A[axis])  / sqrt( 1.0 + square(cos_[axis])  * square(tan(A[1-axis]))); //reverse calculation of RwGyro from Awz angles
      }
      RGyro[YAW] = sqrt(abs(1.0 - square(RGyro[ROLL]) - square(RGyro[PITCH])));
      for (axis=0;axis<3;axis++)
        REst[axis] = (accADC[axis]/R + wGyro* RGyro[axis])  * invW; //combine Accelerometer and gyro readings
      small_angle=0;
    }
    #if defined(HMC5843) || defined(HMC5883)
      mag[PITCH] = -magADC[PITCH]*cos_[PITCH]+magADC[ROLL]*A[ROLL]*A[PITCH]+magADC[YAW]*cos_[ROLL]*A[PITCH];
      mag[ROLL] = magADC[ROLL]*cos_[ROLL]-magADC[YAW]*A[ROLL];
      heading = -degrees(atan2(mag[PITCH],mag[ROLL]));
    #endif
  }
  for (axis=0;axis<2;axis++) angle[axis] = A[axis]*572.9577951; //angle in multiple of 0.1 degree
}

#else


// **************************************************
// Simplified IMU based on "Complementary Filter"
// Inspired by http://starlino.com/imu_guide.html
//
// adapted by ziss_dm : http://wbb.multiwii.com/viewtopic.php?f=8&t=198
//
// The following ideas was used in this project:
// 1) Rotation matrix: http://en.wikipedia.org/wiki/Rotation_matrix
// 2) Small-angle approximation: http://en.wikipedia.org/wiki/Small-angle_approximation
// 3) C. Hastings approximation for atan2()
// 4) Optimization tricks: http://www.hackersdelight.org/
//
// Currently Magnetometer uses separate CF which is used only
// for heading approximation.
//
// Modified: 19/04/2011  by ziss_dm
// Version: V1.1
//
// code size deduction and tmp vector intermediate step for vector rotation computation: October 2011 by Alex
// **************************************************

//******  advanced users settings *******************
/* Set the Low Pass Filter factor for ACC */
/* Increasing this value would reduce ACC noise (visible in GUI), but would increase ACC lag time*/
/* Comment this if  you do not want filter at all.*/
/* Default WMC value: 8*/
#define ACC_LPF_FACTOR 8

/* Set the Low Pass Filter factor for Magnetometer */
/* Increasing this value would reduce Magnetometer noise (not visible in GUI), but would increase Magnetometer lag time*/
/* Comment this if  you do not want filter at all.*/
/* Default WMC value: n/a*/
//#define MG_LPF_FACTOR 4

/* Set the Gyro Weight for Gyro/Acc complementary filter */
/* Increasing this value would reduce and delay Acc influence on the output of the filter*/
/* Default WMC value: 300*/
#define GYR_CMPF_FACTOR 310.0f

/* Set the Gyro Weight for Gyro/Magnetometer complementary filter */
/* Increasing this value would reduce and delay Magnetometer influence on the output of the filter*/
/* Default WMC value: n/a*/
#define GYR_CMPFM_FACTOR 200.0f

//****** end of advanced users settings *************

#define INV_GYR_CMPF_FACTOR   (1.0f / (GYR_CMPF_FACTOR  + 1.0f))
#define INV_GYR_CMPFM_FACTOR  (1.0f / (GYR_CMPFM_FACTOR + 1.0f))
#if GYRO
  #define GYRO_SCALE ((2380 * PI)/((32767.0f / 4.0f ) * 180.0f * 1000000.0f)) //should be 2279.44 but 2380 gives better result
  // +-2000/sec deg scale
  //#define GYRO_SCALE ((200.0f * PI)/((32768.0f / 5.0f / 4.0f ) * 180.0f * 1000000.0f) * 1.5f)     
  // +- 200/sec deg scale
  // 1.5 is emperical, not sure what it means
  // should be in rad/sec
#else
  #define GYRO_SCALE (1.0f/200e6f)
  // empirical, depends on WMP on IDG datasheet, tied of deg/ms sensibility
  // !!!!should be adjusted to the rad/sec
#endif 
// Small angle approximation
#define ssin(val) (val)
#define scos(val) 1.0f

typedef struct fp_vector {
  float X;
  float Y;
  float Z;
} t_fp_vector_def;

typedef union {
  float   A[3];
  t_fp_vector_def V;
} t_fp_vector;

int16_t _atan2(float y, float x){
  #define fp_is_neg(val) ((((byte*)&val)[3] & 0x80) != 0)
  float z = y / x;
  int16_t zi = abs(int16_t(z * 100)); 
  int8_t y_neg = fp_is_neg(y);
  if ( zi < 100 ){
    if (zi > 10) 
     z = z / (1.0f + 0.28f * z * z);
   if (fp_is_neg(x)) {
     if (y_neg) z -= PI;
     else z += PI;
   }
  } else {
   z = (PI / 2.0f) - z / (z * z + 0.28f);
   if (y_neg) z -= PI;
  }
  z *= (180.0f / PI * 10); 
  return z;
}

// Rotate Estimated vector(s) with small angle approximation, according to the gyro data
void rotateV(struct fp_vector *v,float* delta) {
  fp_vector v_tmp = *v;
  v->Z -= delta[ROLL]  * v_tmp.X + delta[PITCH] * v_tmp.Y;
  v->X += delta[ROLL]  * v_tmp.Z - delta[YAW]   * v_tmp.Y;
  v->Y += delta[PITCH] * v_tmp.Z + delta[YAW]   * v_tmp.X; 
}

void getEstimatedAttitude(){
  uint8_t axis;
  int16_t accMag = 0;
  static t_fp_vector EstG,EstM;
  static int16_t mgSmooth[3],accTemp[3];  //projection of smoothed and normalized magnetic vector on x/y/z axis, as measured by magnetometer
  static uint16_t previousT;
  uint16_t currentT = micros();
  float scale, deltaGyroAngle[3];

  scale = (currentT - previousT) * GYRO_SCALE;
  previousT = currentT;

  // Initialization
  for (axis = 0; axis < 3; axis++) {
    deltaGyroAngle[axis] = gyroADC[axis]  * scale;
    #if defined(ACC_LPF_FACTOR)
      accTemp[axis] = (accTemp[axis] - (accTemp[axis] >>4)) + accADC[axis];
      accSmooth[axis] = accTemp[axis]>>4;
      #define ACC_VALUE accSmooth[axis]
    #else  
      accSmooth[axis] = accADC[axis];
      #define ACC_VALUE accADC[axis]
    #endif
    accMag += (ACC_VALUE * 10 / (int16_t)acc_1G) * (ACC_VALUE * 10 / (int16_t)acc_1G);
    #if MAG
      #if defined(MG_LPF_FACTOR)
        mgSmooth[axis] = (mgSmooth[axis] * (MG_LPF_FACTOR - 1) + magADC[axis]) / MG_LPF_FACTOR; // LPF for Magnetometer values
        #define MAG_VALUE mgSmooth[axis]
      #else  
        #define MAG_VALUE magADC[axis]
      #endif
    #endif
  }

  rotateV(&EstG.V,deltaGyroAngle);
  #if MAG
    rotateV(&EstM.V,deltaGyroAngle);
  #endif 

  if ( abs(accSmooth[ROLL])<acc_25deg && abs(accSmooth[PITCH])<acc_25deg && accSmooth[YAW]>0)
    smallAngle25 = 1;
  else
    smallAngle25 = 0;

  // Apply complimentary filter (Gyro drift correction)
  // If accel magnitude >1.4G or <0.6G and ACC vector outside of the limit range => we neutralize the effect of accelerometers in the angle estimation.
  // To do that, we just skip filter, as EstV already rotated by Gyro
  if ( ( 36 < accMag && accMag < 196 ) || smallAngle25 )
    for (axis = 0; axis < 3; axis++) {
      int16_t acc = ACC_VALUE;
      #if not defined(TRUSTED_ACCZ)
        if (smallAngle25 && axis == YAW)
          //We consider ACCZ = acc_1G when the acc on other axis is small.
          //It's a tweak to deal with some configs where ACC_Z tends to a value < acc_1G when high throttle is applied.
          //This tweak applies only when the multi is not in inverted position
          acc = acc_1G;      
      #endif
      EstG.A[axis] = (EstG.A[axis] * GYR_CMPF_FACTOR + acc) * INV_GYR_CMPF_FACTOR;
    }
  #if MAG
    for (axis = 0; axis < 3; axis++)
      EstM.A[axis] = (EstM.A[axis] * GYR_CMPFM_FACTOR  + MAG_VALUE) * INV_GYR_CMPFM_FACTOR;
  #endif
  
  // Attitude of the estimated vector
  angle[ROLL]  =  _atan2(EstG.V.X , EstG.V.Z) ;
  angle[PITCH] =  _atan2(EstG.V.Y , EstG.V.Z) ;
  #if MAG
    // Attitude of the cross product vector GxM
    heading = _atan2( EstG.V.X * EstM.V.Z - EstG.V.Z * EstM.V.X , EstG.V.Z * EstM.V.Y - EstG.V.Y * EstM.V.Z  ) / 10;
  #endif
}
#endif

float InvSqrt (float x){ 
  union{  
    int32_t i;  
    float   f; 
  } conv; 
  conv.f = x; 
  conv.i = 0x5f3759df - (conv.i >> 1); 
  return 0.5f * conv.f * (3.0f - x * conv.f * conv.f);
} 
int32_t isq(int32_t x){return x * x;}

#define UPDATE_INTERVAL 25000    // 40hz update rate (20hz LPF on acc)
#define INIT_DELAY      4000000  // 4 sec initialization delay
#define Kp1 0.55f                // PI observer velocity gain 
#define Kp2 1.0f                 // PI observer position gain
#define Ki  0.001f               // PI observer integral gain (bias cancellation)
#define dt  (UPDATE_INTERVAL / 1000000.0f)

void getEstimatedAltitude(){
  static uint8_t inited = 0;
  static int16_t AltErrorI = 0;
  static float AccScale  = 0.0f;
  static uint32_t deadLine = INIT_DELAY;
  int16_t AltError;
  int16_t InstAcc;
  int16_t Delta;
  
  if (currentTime < deadLine) return;
  deadLine = currentTime + UPDATE_INTERVAL; 
  // Soft start

  if (!inited) {
    inited = 1;
    EstAlt = BaroAlt;
    EstVelocity = 0;
    AltErrorI = 0;
    AccScale = 100 * 9.80665f / acc_1G;
  }
  // Estimation Error
  AltError = BaroAlt - EstAlt; 
  AltErrorI += AltError;
  AltErrorI=constrain(AltErrorI,-25000,+25000);
  // Gravity vector correction and projection to the local Z
  //InstAcc = (accADC[YAW] * (1 - acc_1G * InvSqrt(isq(accADC[ROLL]) + isq(accADC[PITCH]) + isq(accADC[YAW])))) * AccScale + (Ki) * AltErrorI;
  #if defined(TRUSTED_ACCZ)
    InstAcc = (accADC[YAW] * (1 - acc_1G * InvSqrt(isq(accADC[ROLL]) + isq(accADC[PITCH]) + isq(accADC[YAW])))) * AccScale +  AltErrorI / 1000;
  #else
    InstAcc = AltErrorI / 1000;
  #endif
  
  // Integrators
  Delta = InstAcc * dt + (Kp1 * dt) * AltError;
  EstAlt += (EstVelocity/5 + Delta) * (dt / 2) + (Kp2 * dt) * AltError;
  EstVelocity += Delta*10;
}
