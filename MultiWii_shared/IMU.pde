
void computeIMU () {
  uint8_t axis;
  static int16_t gyroADCprevious[3] = {0,0,0};
  int16_t gyroADCp[3];
  int16_t gyroADCinter[3];
  static uint32_t timeInterleave = 0;

  //we separate the 2 situations because reading gyro values with a gyro only setup can be acchieved at a higher rate
  //gyro+nunchuk: we must wait for a quite high delay betwwen 2 reads to get both WM+ and Nunchuk data. It works with 3ms
  //gyro only: the delay to read 2 consecutive values can be reduced to only 0.65ms
  if (!ACC && nunchuk) {
    annexCode();
    while((micros()-timeInterleave)<INTERLEAVING_DELAY) ; //interleaving delay between 2 consecutive reads
    timeInterleave=micros();
    WMP_getRawADC();
    getEstimatedAttitude(); // computation time must last less than one interleaving delay
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
    #if ACC
      ACC_getADC();
      getEstimatedAttitude();
    #endif
    #if GYRO
      Gyro_getADC();
    #else
      WMP_getRawADC();
    #endif
    for (axis = 0; axis < 3; axis++)
      gyroADCp[axis] =  gyroADC[axis];
    timeInterleave=micros();
    annexCode();
    if ((micros()-timeInterleave)>650) {
       annex650_overrun_count++;
    } else {
       while((micros()-timeInterleave)<650) ; //empirical, interleaving delay between 2 consecutive reads
    }
    #if GYRO
      Gyro_getADC();
    #else
      WMP_getRawADC();
    #endif
    for (axis = 0; axis < 3; axis++) {
      gyroADCinter[axis] =  gyroADC[axis]+gyroADCp[axis];
      // empirical, we take a weighted value of the current and the previous values
      gyroData[axis] = (gyroADCinter[axis]+gyroADCprevious[axis]+1)/3;
      gyroADCprevious[axis] = gyroADCinter[axis]/2;
      if (!ACC) accADC[axis]=0;
    }
  }
  #if defined(GYRO_SMOOTHING)
    static uint8_t Smoothing[3]  = GYRO_SMOOTHING; // How much to smoothen with per axis
    static int16_t gyroSmooth[3] = {0,0,0};
    for (axis = 0; axis < 3; axis++) {
      gyroData[axis] = (gyroSmooth[axis]*(Smoothing[axis]-1)+gyroData[axis]+1)/Smoothing[axis];
      gyroSmooth[axis] = gyroData[axis];
    }
  #elif defined(TRI)
    static int16_t gyroYawSmooth = 0;
    gyroData[YAW] = (gyroYawSmooth*2+gyroData[YAW]+1)/3;
    gyroYawSmooth = gyroData[YAW];
  #endif
}

// **************************************************
// Simplified IMU based on "Complementary Filter"
// Inspired by http://starlino.com/imu_guide.html
//
// adapted by ziss_dm : http://www.multiwii.com/forum/viewtopic.php?f=8&t=198
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
// code size reduction and tmp vector intermediate step for vector rotation computation: October 2011 by Alex
// **************************************************

//******  advanced users settings *******************
/* Set the Low Pass Filter factor for ACC */
/* Increasing this value would reduce ACC noise (visible in GUI), but would increase ACC lag time*/
/* Comment this if  you do not want filter at all.*/
/* Default WMC value: 8*/
#define ACC_LPF_FACTOR 4

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
  #define fp_is_neg(val) ((((uint8_t*)&val)[3] & 0x80) != 0)
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
  int32_t accMag = 0;
  static t_fp_vector EstG;
#if MAG
  static t_fp_vector EstM;
#endif
#if defined(MG_LPF_FACTOR)
  static int16_t mgSmooth[3]; 
#endif
#if defined(ACC_LPF_FACTOR)
  static int16_t accTemp[3];  //projection of smoothed and normalized magnetic vector on x/y/z axis, as measured by magnetometer
#endif
  static uint16_t previousT;
  uint16_t currentT = micros();
  float scale, deltaGyroAngle[3];

  scale = (currentT - previousT) * GYRO_SCALE;
  previousT = currentT;

  // Initialization
  for (axis = 0; axis < 3; axis++) {
    deltaGyroAngle[axis] = gyroADC[axis]  * scale;
    #if defined(ACC_LPF_FACTOR)
      accTemp[axis] = (accTemp[axis] - (accTemp[axis] >>ACC_LPF_FACTOR)) + accADC[axis];
      accSmooth[axis] = accTemp[axis]>>ACC_LPF_FACTOR;
      #define ACC_VALUE accSmooth[axis]
    #else  
      accSmooth[axis] = accADC[axis];
      #define ACC_VALUE accADC[axis]
    #endif
//    accMag += (ACC_VALUE * 10 / (int16_t)acc_1G) * (ACC_VALUE * 10 / (int16_t)acc_1G);
    accMag += (int32_t)ACC_VALUE*ACC_VALUE ;
    #if MAG
      #if defined(MG_LPF_FACTOR)
        mgSmooth[axis] = (mgSmooth[axis] * (MG_LPF_FACTOR - 1) + magADC[axis]) / MG_LPF_FACTOR; // LPF for Magnetometer values
        #define MAG_VALUE mgSmooth[axis]
      #else  
        #define MAG_VALUE magADC[axis]
      #endif
    #endif
  }
  accMag = accMag*100/((int32_t)acc_1G*acc_1G);
  
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
      #if !defined(TRUSTED_ACCZ)
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

#define UPDATE_INTERVAL 25000    // 40hz update rate (20hz LPF on acc)
#define INIT_DELAY      4000000  // 4 sec initialization delay
#define BARO_TAB_SIZE   40

void getEstimatedAltitude(){
  uint8_t index;
  static uint32_t deadLine = INIT_DELAY;

  static int16_t BaroHistTab[BARO_TAB_SIZE];
  static int8_t BaroHistIdx;
  static int32_t BaroHigh,BaroLow;
  int32_t temp32;
  int16_t last;
  
  if (currentTime < deadLine) return;
  deadLine = currentTime + UPDATE_INTERVAL; 

  //**** Alt. Set Point stabilization PID ****
  //calculate speed for D calculation
  last = BaroHistTab[BaroHistIdx];
  BaroHistTab[BaroHistIdx] = BaroAlt/10;
  BaroHigh += BaroHistTab[BaroHistIdx];
  index = (BaroHistIdx + (BARO_TAB_SIZE/2))%BARO_TAB_SIZE;
  BaroHigh -= BaroHistTab[index];
  BaroLow  += BaroHistTab[index];
  BaroLow  -= last;

  BaroHistIdx++;
  if (BaroHistIdx == BARO_TAB_SIZE) BaroHistIdx = 0;

  BaroPID = 0;
  //D
  temp32 = D8[PIDALT]*(BaroHigh - BaroLow) / 40;
  BaroPID-=temp32;

  EstAlt = BaroHigh*10/(BARO_TAB_SIZE/2);
  
  temp32 = AltHold - EstAlt;
  if (abs(temp32) < 10 && BaroPID < 10) BaroPID = 0;  //remove small D parametr to reduce noise near zoro position
  
  //P
  BaroPID += P8[PIDALT]*constrain(temp32,(-2)*P8[PIDALT],2*P8[PIDALT])/100;   
  BaroPID = constrain(BaroPID,-150,+150); //sum of P and D should be in range 150

  //I
  errorAltitudeI += temp32*I8[PIDALT]/50;
  errorAltitudeI = constrain(errorAltitudeI,-30000,30000);
  temp32 = errorAltitudeI / 500; //I in range +/-60
  BaroPID+=temp32;
}
