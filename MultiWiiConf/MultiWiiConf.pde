import processing.serial.*; // serial library
import controlP5.*; // controlP5 library
import processing.opengl.*;

Serial g_serial;
ControlP5 controlP5;
Textlabel txtlblWhichcom; 
ListBox commListbox;

int CHECKBOXITEMS=11;
int PIDITEMS=8;
int commListMax;

cGraph g_graph;
int windowsX    = 800;        int windowsY    = 540;
int xGraph      = 10;         int yGraph      = 325;
int xObj        = 700;        int yObj        = 450;
int xParam      = 120;        int yParam      = 10;
int xRC         = 650;        int yRC         = 15;
int xMot        = 490;        int yMot        = 30;
int xButton     = 485;        int yButton     = 185;
int xBox        = xParam+190; int yBox        = yParam+70;

boolean axGraph =true,ayGraph=true,azGraph=true,gxGraph=true,gyGraph=true,gzGraph=true,altGraph=true,headGraph=true, magxGraph =true,magyGraph=true,magzGraph=true,
        debug1Graph = false,debug2Graph = false,debug3Graph = false,debug4Graph = false;

int multiType;  // 1 for tricopter, 2 for quad+, 3 for quadX, ...

cDataArray accPITCH   = new cDataArray(100), accROLL    = new cDataArray(100), accYAW     = new cDataArray(100),
           gyroPITCH  = new cDataArray(100), gyroROLL   = new cDataArray(100), gyroYAW    = new cDataArray(100),
           magxData   = new cDataArray(100), magyData   = new cDataArray(100), magzData   = new cDataArray(100),
           altData    = new cDataArray(100), headData   = new cDataArray(100),
           debug1Data = new cDataArray(100), debug2Data = new cDataArray(100), debug3Data = new cDataArray(100),debug4Data = new cDataArray(100);

private static final int ROLL = 0, PITCH = 1, YAW = 2, ALT = 3, VEL = 4, LEVEL = 5, MAG = 6;

Numberbox confP[] = new Numberbox[PIDITEMS], confI[] = new Numberbox[PIDITEMS], confD[] = new Numberbox[PIDITEMS];
int       byteP[] = new int[PIDITEMS],       byteI[] = new int[PIDITEMS],       byteD[] = new int[PIDITEMS];

Numberbox confRC_RATE, confRC_EXPO, rollPitchRate, yawRate, dynamic_THR_PID;

int  byteRC_RATE,byteRC_EXPO, byteRollPitchRate,byteYawRate, byteDynThrPID;

Slider rcStickThrottleSlider,rcStickRollSlider,rcStickPitchSlider,rcStickYawSlider,rcStickAUX1Slider,rcStickAUX2Slider,rcStickAUX3Slider,rcStickAUX4Slider;

Slider servoSliderH[] = new Slider[8],
       servoSliderV[] = new Slider[8],
       motSlider[]   = new Slider[8];

Slider axSlider,aySlider,azSlider,gxSlider,gySlider,gzSlider , magxSlider,magySlider,magzSlider , altSlider,headSlider,
       debug1Slider,debug2Slider,debug3Slider,debug4Slider;

Slider scaleSlider;

Button buttonREAD,buttonRESET,buttonWRITE,buttonCALIBRATE_ACC,buttonCALIBRATE_MAG,buttonSTART,buttonSTOP,
       buttonAcc,buttonBaro,buttonMag,buttonGPS,buttonSonar,buttonOptic;

color yellow_ = color(200, 200, 20), green_ = color(30, 120, 30), red_ = color(120, 30, 30),
grey_ = color(30, 30, 30);
boolean graphEnable = false;

int version,versionMisMatch;
float gx,gy,gz,ax,ay,az,magx,magy,magz,alt,head,angx,angy,debug1,debug2,debug3,debug4;
int GPS_distanceToHome, GPS_directionToHome,
    GPS_numSat,GPS_fix,GPS_update,GPS_altitude,GPS_speed,
    GPS_latitude,GPS_longitude,
    init_com,graph_on,pMeterSum,intPowerTrigger,bytevbat;

Numberbox confPowerTrigger;

float mot[] = new float[8],
      servo[] = new float[8],
      rcThrottle = 1500,rcRoll = 1500,rcPitch = 1500,rcYaw =1500,
      rcAUX1=1500, rcAUX2=1500, rcAUX3=1500, rcAUX4=1500;

int cycleTime,i2cError;

CheckBox checkbox1[] = new CheckBox[CHECKBOXITEMS],
         checkbox2[] = new CheckBox[CHECKBOXITEMS];
int activation[] = new int[CHECKBOXITEMS];

Button buttonCheckbox[] = new Button[CHECKBOXITEMS];
String buttonCheckboxLabel[] = {   "LEVEL",  "BARO",  "MAG",  "CAMSTAB",  "CAMTRIG",  "ARM",  "GPS HOME",  "GPS HOLD",  "PASSTHRU",  "HEADFREE",  "BEEPER", }; 
PFont font8,font12,font15;

// coded by Eberhard Rensch
// Truncates a long port name for better (readable) display in the GUI
String shortifyPortName(String portName, int maxlen)  {
  String shortName = portName;
  if(shortName.startsWith("/dev/")) shortName = shortName.substring(5);  
  if(shortName.startsWith("tty.")) shortName = shortName.substring(4); // get rid of leading tty. part of device name
  if(portName.length()>maxlen) shortName = shortName.substring(0,(maxlen-1)/2) + "~" +shortName.substring(shortName.length()-(maxlen-(maxlen-1)/2));
  if(shortName.startsWith("cu.")) shortName = "";// only collect the corresponding tty. devices
  return shortName;
}

controlP5.Controller hideLabel(controlP5.Controller c) {
  c.setLabel("");
  c.setLabelVisible(false);
  return c;
}

void setup() {
  size(windowsX,windowsY,OPENGL);
  frameRate(20); 

  font8 = createFont("Arial bold",8,false);font12 = createFont("Arial bold",12,false);font15 = createFont("Arial bold",15,false);

  controlP5 = new ControlP5(this); // initialize the GUI controls
  controlP5.setControlFont(font12);

  g_graph  = new cGraph(xGraph+110,yGraph, 480, 200);
  commListbox = controlP5.addListBox("portComList",5,65,110,240); // make a listbox and populate it with the available comm ports

  commListbox.captionLabel().set("PORT COM");
  commListbox.setColorBackground(red_);
  for(int i=0;i<Serial.list().length;i++) {
    String pn = shortifyPortName(Serial.list()[i], 13);
    if (pn.length() >0 ) commListbox.addItem(pn,i); // addItem(name,value)
    commListMax = i;
  }
  commListbox.addItem("Close Comm",++commListMax); // addItem(name,value)
  // text label for which comm port selected
  txtlblWhichcom = controlP5.addTextlabel("txtlblWhichcom","No Port Selected",5,42); // textlabel(name,text,x,y)
    
  buttonSTART = controlP5.addButton("bSTART",1,xGraph+110,yGraph-25,40,19); buttonSTART.setLabel("START"); buttonSTART.setColorBackground(red_);
  buttonSTOP = controlP5.addButton("bSTOP",1,xGraph+160,yGraph-25,40,19); buttonSTOP.setLabel("STOP"); buttonSTOP.setColorBackground(red_);

  buttonAcc = controlP5.addButton("bACC",1,xButton,yButton,45,15); buttonAcc.setColorBackground(red_);buttonAcc.setLabel("ACC");
  buttonBaro = controlP5.addButton("bBARO",1,xButton+50,yButton,45,15); buttonBaro.setColorBackground(red_);buttonBaro.setLabel("BARO");
  buttonMag = controlP5.addButton("bMAG",1,xButton+100,yButton,45,15); buttonMag.setColorBackground(red_);buttonMag.setLabel("MAG");
  buttonGPS = controlP5.addButton("bGPS",1,xButton,yButton+17,45,15); buttonGPS.setColorBackground(red_);buttonGPS.setLabel("GPS");
  buttonSonar = controlP5.addButton("bSonar",1,xButton+50,yButton+17,45,15); buttonSonar.setColorBackground(red_);buttonSonar.setLabel("SONAR");
  buttonOptic = controlP5.addButton("bOptic",1,xButton+100,yButton+17,45,15); buttonOptic.setColorBackground(grey_);buttonOptic.setLabel("OPTIC");

  color c,black;
  black = color(0,0,0);
  int xo = xGraph-7;
  int x = xGraph+40;
  int y1= yGraph+10;  //ACC
  int y2= yGraph+55;  //GYRO
  int y5= yGraph+100; //MAG
  int y3= yGraph+150; //ALT
  int y4= yGraph+165; //HEAD
  int y7= yGraph+185; //GPS
  int y6= yGraph+205; //DEBUG

  Toggle tACC_ROLL =     controlP5.addToggle("ACC_ROLL",true,x,y1+10,20,10);tACC_ROLL.setColorActive(color(255, 0, 0));tACC_ROLL.setColorBackground(black);tACC_ROLL.setLabel(""); 
  Toggle tACC_PITCH =   controlP5.addToggle("ACC_PITCH",true,x,y1+20,20,10);tACC_PITCH.setColorActive(color(0, 255, 0));tACC_PITCH.setColorBackground(black);tACC_PITCH.setLabel(""); 
  Toggle tACC_Z =           controlP5.addToggle("ACC_Z",true,x,y1+30,20,10);tACC_Z.setColorActive(color(0, 0, 255));tACC_Z.setColorBackground(black);tACC_Z.setLabel(""); 
  Toggle tGYRO_ROLL =   controlP5.addToggle("GYRO_ROLL",true,x,y2+10,20,10);tGYRO_ROLL.setColorActive(color(200, 200, 0));tGYRO_ROLL.setColorBackground(black);tGYRO_ROLL.setLabel(""); 
  Toggle tGYRO_PITCH = controlP5.addToggle("GYRO_PITCH",true,x,y2+20,20,10);tGYRO_PITCH.setColorActive(color(0, 255, 255));tGYRO_PITCH.setColorBackground(black);tGYRO_PITCH.setLabel(""); 
  Toggle tGYRO_YAW =     controlP5.addToggle("GYRO_YAW",true,x,y2+30,20,10);tGYRO_YAW.setColorActive(color(255, 0, 255));tGYRO_YAW.setColorBackground(black);tGYRO_YAW.setLabel(""); 
  Toggle tBARO =               controlP5.addToggle("BARO",true,x,y3 ,20,10);tBARO.setColorActive(color(125, 125, 125));tBARO.setColorBackground(black);tBARO.setLabel(""); 
  Toggle tHEAD =               controlP5.addToggle("HEAD",true,x,y4 ,20,10);tHEAD.setColorActive(color(225, 225, 125));tHEAD.setColorBackground(black);tHEAD.setLabel(""); 
  Toggle tMAGX =             controlP5.addToggle("MAGX",true,x,y5+10,20,10);tMAGX.setColorActive(color(50, 100, 150));tMAGX.setColorBackground(black);tMAGX.setLabel(""); 
  Toggle tMAGY =             controlP5.addToggle("MAGY",true,x,y5+20,20,10);tMAGY.setColorActive(color(100, 50, 150));tMAGY.setColorBackground(black);tMAGY.setLabel(""); 
  Toggle tMAGZ =             controlP5.addToggle("MAGZ",true,x,y5+30,20,10);tMAGZ.setColorActive(color(150, 100, 50));tMAGZ.setColorBackground(black);tMAGZ.setLabel(""); 
  Toggle tDEBUG1 =         controlP5.addToggle("DEBUG1",true,x+70,y6,20,10);tDEBUG1.setColorActive(color(150, 100, 50));tDEBUG1.setColorBackground(black);tDEBUG1.setLabel("");tDEBUG1.setValue(0);
  Toggle tDEBUG2 =         controlP5.addToggle("DEBUG2",true,x+190,y6,20,10);tDEBUG2.setColorActive(color(150, 100, 50));tDEBUG2.setColorBackground(black);tDEBUG2.setLabel("");tDEBUG2.setValue(0);
  Toggle tDEBUG3 =         controlP5.addToggle("DEBUG3",true,x+310,y6,20,10);tDEBUG3.setColorActive(color(150, 100, 50));tDEBUG3.setColorBackground(black);tDEBUG3.setLabel("");tDEBUG3.setValue(0);
  Toggle tDEBUG4 =         controlP5.addToggle("DEBUG4",true,x+430,y6,20,10);tDEBUG4.setColorActive(color(150, 100, 50));tDEBUG4.setColorBackground(black);tDEBUG4.setLabel("");tDEBUG4.setValue(0);

  controlP5.addTextlabel("acclabel","ACC",xo,y1);
  controlP5.addTextlabel("accrolllabel","   ROLL",xo,y1+10);
  controlP5.addTextlabel("accpitchlabel","   PITCH",xo,y1+20);
  controlP5.addTextlabel("acczlabel","   Z",xo,y1+30);
  controlP5.addTextlabel("gyrolabel","GYRO",xo,y2);
  controlP5.addTextlabel("gyrorolllabel","   ROLL",xo,y2+10);
  controlP5.addTextlabel("gyropitchlabel","   PITCH",xo,y2+20);
  controlP5.addTextlabel("gyroyawlabel","   YAW",xo,y2+30);
  controlP5.addTextlabel("maglabel","MAG",xo,y5);
  controlP5.addTextlabel("magrolllabel","   ROLL",xo,y5+10);
  controlP5.addTextlabel("magpitchlabel","   PITCH",xo,y5+20);
  controlP5.addTextlabel("magyawlabel","   YAW",xo,y5+30);
  controlP5.addTextlabel("altitudelabel","ALT",xo,y3);
  controlP5.addTextlabel("headlabel","HEAD",xo,y4);
  controlP5.addTextlabel("debug1","debug1",x+90,y6);
  controlP5.addTextlabel("debug2","debug2",x+210,y6);
  controlP5.addTextlabel("debug3","debug3",x+330,y6);
  controlP5.addTextlabel("debug4","debug4",x+450,y6);

  axSlider   =       controlP5.addSlider("axSlider",-1000,+1000,0,x+20,y1+10,50,10);axSlider.setDecimalPrecision(0);axSlider.setLabel("");
  aySlider   =       controlP5.addSlider("aySlider",-1000,+1000,0,x+20,y1+20,50,10);aySlider.setDecimalPrecision(0);aySlider.setLabel("");
  azSlider   =       controlP5.addSlider("azSlider",-1000,+1000,0,x+20,y1+30,50,10);azSlider.setDecimalPrecision(0);azSlider.setLabel("");
  gxSlider   =       controlP5.addSlider("gxSlider",-5000,+5000,0,x+20,y2+10,50,10);gxSlider.setDecimalPrecision(0);gxSlider.setLabel("");
  gySlider   =       controlP5.addSlider("gySlider",-5000,+5000,0,x+20,y2+20,50,10);gySlider.setDecimalPrecision(0);gySlider.setLabel("");
  gzSlider   =       controlP5.addSlider("gzSlider",-5000,+5000,0,x+20,y2+30,50,10);gzSlider.setDecimalPrecision(0);gzSlider.setLabel("");
  altSlider  =       controlP5.addSlider("altSlider",-30000,+30000,0,x+20,y3 ,50,10);altSlider.setDecimalPrecision(2);altSlider.setLabel("");
  headSlider  =      controlP5.addSlider("headSlider",-200,+200,0,x+20,y4  ,50,10);headSlider.setDecimalPrecision(0);headSlider.setLabel("");
  magxSlider  =      controlP5.addSlider("magxSlider",-5000,+5000,0,x+20,y5+10,50,10);magxSlider.setDecimalPrecision(0);magxSlider.setLabel("");
  magySlider  =      controlP5.addSlider("magySlider",-5000,+5000,0,x+20,y5+20,50,10);magySlider.setDecimalPrecision(0);magySlider.setLabel("");
  magzSlider  =      controlP5.addSlider("magzSlider",-5000,+5000,0,x+20,y5+30,50,10);magzSlider.setDecimalPrecision(0);magzSlider.setLabel("");
  debug1Slider  =    controlP5.addSlider("debug1Slider",-32000,+32000,0,x+130,y6,50,10);debug1Slider.setDecimalPrecision(0);debug1Slider.setLabel("");
  debug2Slider  =    controlP5.addSlider("debug2Slider",-32000,+32000,0,x+250,y6,50,10);debug2Slider.setDecimalPrecision(0);debug2Slider.setLabel("");
  debug3Slider  =    controlP5.addSlider("debug3Slider",-32000,+32000,0,x+370,y6,50,10);debug3Slider.setDecimalPrecision(0);debug3Slider.setLabel("");
  debug4Slider  =    controlP5.addSlider("debug4Slider",-32000,+32000,0,x+490,y6,50,10);debug4Slider.setDecimalPrecision(0);debug4Slider.setLabel("");

  for(int i=0;i<8;i++) {
    confP[i] = (controlP5.Numberbox) hideLabel(controlP5.addNumberbox("confP"+i,0,xParam+40,yParam+20+i*20,30,14));
    confP[i].setColorBackground(red_);confP[i].setMin(0);confP[i].setDirection(Controller.HORIZONTAL);confP[i].setDecimalPrecision(1);confP[i].setMultiplier(0.1);confP[i].setMax(20);
    confI[i] = (controlP5.Numberbox) hideLabel(controlP5.addNumberbox("confI"+i,0,xParam+75,yParam+20+i*20,40,14));
    confI[i].setColorBackground(red_);confI[i].setMin(0);confI[i].setDirection(Controller.HORIZONTAL);confI[i].setDecimalPrecision(3);confI[i].setMultiplier(0.001);confI[i].setMax(0.250);
    confD[i] = (controlP5.Numberbox) hideLabel(controlP5.addNumberbox("confD"+i,0,xParam+120,yParam+20+i*20,30,14));
    confD[i].setColorBackground(red_);confD[i].setMin(0);confD[i].setDirection(Controller.HORIZONTAL);confD[i].setDecimalPrecision(0);confD[i].setMultiplier(1);confD[i].setMax(100);}
  confI[7].hide();confD[7].hide();

  rollPitchRate = (controlP5.Numberbox) hideLabel(controlP5.addNumberbox("rollPitchRate",0,xParam+160,yParam+30,30,14));rollPitchRate.setDecimalPrecision(2);rollPitchRate.setMultiplier(0.01);
  rollPitchRate.setDirection(Controller.HORIZONTAL);rollPitchRate.setMin(0);rollPitchRate.setMax(1);rollPitchRate.setColorBackground(red_);
  yawRate = (controlP5.Numberbox) hideLabel(controlP5.addNumberbox("yawRate",0,xParam+160,yParam+60,30,14));yawRate.setDecimalPrecision(2);yawRate.setMultiplier(0.01);
  yawRate.setDirection(Controller.HORIZONTAL);yawRate.setMin(0);yawRate.setMax(1);yawRate.setColorBackground(red_); 
  dynamic_THR_PID = (controlP5.Numberbox) hideLabel(controlP5.addNumberbox("dynamic_THR_PID",0,xParam+300,yParam+12,30,14));dynamic_THR_PID.setDecimalPrecision(2);dynamic_THR_PID.setMultiplier(0.01);
  dynamic_THR_PID.setDirection(Controller.HORIZONTAL);dynamic_THR_PID.setMin(0);dynamic_THR_PID.setMax(1);dynamic_THR_PID.setColorBackground(red_);

  confRC_RATE = controlP5.addNumberbox("RC RATE",1,xParam+40,yParam+213,30,14);confRC_RATE.setDecimalPrecision(2);confRC_RATE.setMultiplier(0.01);confRC_RATE.setLabel("");
  confRC_RATE.setDirection(Controller.HORIZONTAL);confRC_RATE.setMin(0);confRC_RATE.setMax(2.5);confRC_RATE.setColorBackground(red_);
  confRC_EXPO = controlP5.addNumberbox("RC EXPO",0,xParam+40,yParam+240,30,14);confRC_EXPO.setDecimalPrecision(2);confRC_EXPO.setMultiplier(0.01);confRC_EXPO.setLabel("");
  confRC_EXPO.setDirection(Controller.HORIZONTAL);confRC_EXPO.setMin(0);confRC_EXPO.setMax(1);confRC_EXPO.setColorBackground(red_);

  for(int i=0;i<CHECKBOXITEMS;i++) {
    buttonCheckbox[i] = controlP5.addButton("bcb"+i,1,xBox-30,yBox+20+13*i,68,12);
    buttonCheckbox[i].setColorBackground(red_);buttonCheckbox[i].setLabel(buttonCheckboxLabel[i]);
    checkbox1[i] =  controlP5.addCheckBox("cb"+i,xBox+40,yBox+20+13*i);
    checkbox1[i].setColorActive(color(255));checkbox1[i].setColorBackground(color(120));
    checkbox1[i].setItemsPerRow(6);checkbox1[i].setSpacingColumn(10);
    checkbox1[i].setLabel("");
    hideLabel(checkbox1[i].addItem(i + "1",1));hideLabel(checkbox1[i].addItem(i + "2",2));hideLabel(checkbox1[i].addItem(i + "3",3));
    hideLabel(checkbox1[i].addItem(i + "4",4));hideLabel(checkbox1[i].addItem(i + "5",5));hideLabel(checkbox1[i].addItem(i + "6",6));

    checkbox2[i] =  controlP5.addCheckBox("cb_"+i,xBox+170,yBox+20+13*i);
    checkbox2[i].setColorActive(color(255));checkbox2[i].setColorBackground(color(120));
    checkbox2[i].setItemsPerRow(6);checkbox2[i].setSpacingColumn(10);
    checkbox2[i].setLabel("");
    hideLabel(checkbox2[i].addItem(i + "1_",1));hideLabel(checkbox2[i].addItem(i + "2_",2));hideLabel(checkbox2[i].addItem(i + "3_",3));
    hideLabel(checkbox2[i].addItem(i + "4_",4));hideLabel(checkbox2[i].addItem(i + "5_",5));hideLabel(checkbox2[i].addItem(i + "6_",6));
  }
  
  buttonREAD =          controlP5.addButton("READ",1,xParam+5,yParam+260,50,16);buttonREAD.setColorBackground(red_);
  buttonRESET =         controlP5.addButton("RESET",1,xParam+60,yParam+260,60,16);buttonRESET.setColorBackground(red_);
  buttonWRITE =         controlP5.addButton("WRITE",1,xParam+290,yParam+260,60,16);buttonWRITE.setColorBackground(red_);
  buttonCALIBRATE_ACC = controlP5.addButton("CALIB_ACC",1,xParam+210,yParam+260,70,16);buttonCALIBRATE_ACC.setColorBackground(red_);
  buttonCALIBRATE_MAG = controlP5.addButton("CALIB_MAG",1,xParam+130,yParam+260,70,16);buttonCALIBRATE_MAG.setColorBackground(red_);

  rcStickThrottleSlider = controlP5.addSlider("Throttle",900,2100,1500,xRC,yRC,10,100);rcStickThrottleSlider.setDecimalPrecision(0);
  rcStickPitchSlider =    controlP5.addSlider("Pitch",900,2100,1500,xRC+80,yRC,10,100);rcStickPitchSlider.setDecimalPrecision(0);
  rcStickRollSlider =     controlP5.addSlider("Roll",900,2100,1500,xRC,yRC+120,100,10);rcStickRollSlider.setDecimalPrecision(0);
  rcStickYawSlider  =     controlP5.addSlider("Yaw",900,2100,1500,xRC,yRC+135,100,10);rcStickYawSlider.setDecimalPrecision(0);
  rcStickAUX1Slider =     controlP5.addSlider("AUX1",900,2100,1500,xRC,yRC+150,100,10);rcStickAUX1Slider.setDecimalPrecision(0);
  rcStickAUX2Slider =     controlP5.addSlider("AUX2",900,2100,1500,xRC,yRC+165,100,10);rcStickAUX2Slider.setDecimalPrecision(0);
  rcStickAUX3Slider =     controlP5.addSlider("AUX3",900,2100,1500,xRC,yRC+180,100,10);rcStickAUX3Slider.setDecimalPrecision(0);
  rcStickAUX4Slider =     controlP5.addSlider("AUX4",900,2100,1500,xRC,yRC+195,100,10);rcStickAUX4Slider.setDecimalPrecision(0);

  for(int i=0;i<8;i++) {
    motSlider[i]    = controlP5.addSlider("motSlider"+i,1000,2000,1500,0,0,10,100);motSlider[i].setDecimalPrecision(0);
    servoSliderH[i]  = controlP5.addSlider("ServoH"+i,1000,2000,1500,0,0,100,10);servoSliderH[i].setDecimalPrecision(0);
    servoSliderV[i]  = controlP5.addSlider("ServoV"+i,1000,2000,1500,0,0,10,100);servoSliderV[i].setDecimalPrecision(0);
  }

  scaleSlider = controlP5.addSlider("SCALE",0,10,1,xGraph+515,yGraph,75,20);scaleSlider.setLabel("");
 
  confPowerTrigger = controlP5.addNumberbox("",0,xGraph+50,yGraph-29,40,14);confPowerTrigger.setDecimalPrecision(0);confPowerTrigger.setMultiplier(10);
  confPowerTrigger.setDirection(Controller.HORIZONTAL);confPowerTrigger.setMin(0);confPowerTrigger.setMax(65535);confPowerTrigger.setColorBackground(red_);
}


private static final int
  MSP_IDENT                =100,
  MSP_STATUS               =101,
  MSP_RAW_IMU              =102,
  MSP_SERVO                =103,
  MSP_MOTOR                =104,
  MSP_RC                   =105,
  MSP_RAW_GPS              =106,
  MSP_COMP_GPS             =107,
  MSP_ATTITUDE             =108,
  MSP_ALTITUDE             =109,
  MSP_BAT                  =110,
  MSP_RC_TUNING            =111,
  MSP_PID                  =112,
  MSP_BOX                  =113,
  MSP_MISC                 =114,

  MSP_SET_RAW_RC           =200,
  MSP_SET_RAW_GPS          =201,
  MSP_SET_PID              =202,
  MSP_SET_BOX              =203,
  MSP_SET_RC_TUNING        =204,
  MSP_ACC_CALIBRATION      =205,
  MSP_MAG_CALIBRATION      =206,
  MSP_SET_MISC             =207,
  MSP_RESET_CONF           =208,

  MSP_EEPROM_WRITE         =250,

  MSP_DEBUG                =254
;


int time,time2,time3;

byte checksum=0;
int stateMSP=0,offset=0,dataSize=0,indTX=0;
byte[] inBuf   = new byte[128],
       outBuf_ = new byte[128];
String outBuf;

void serialize16(int a) {
  byte t;
  t = byte(a);            outBuf_[indTX++] = t ; checksum ^= t;
  t = byte((a>>8)&0xff);  outBuf_[indTX++] = t ; checksum ^= t;
}
void serialize8(int a)  {
  outBuf_[indTX++]  = byte(a); checksum ^= a;
}

int p;
int read32() {return (inBuf[p++]&0xff) + ((inBuf[p++]&0xff)<<8) + ((inBuf[p++]&0xff)<<16) + ((inBuf[p++]&0xff)<<24); }
int read16() {return (inBuf[p++]&0xff) + ((inBuf[p++])<<8); }
int read8()  {return inBuf[p++]&0xff;}

int mode;
boolean toggleRead = false,toggleReset = false,toggleCalibAcc = false,toggleCalibMag = false,toggleWrite = false;


void draw() {
  int i,present=0,aa;
  float val,inter,a,b,h;
  int c;
  
  if (init_com==1 && graph_on==1) {
    time=millis();
    if ((time-time2)>50) {
      time2=time;
      outBuf =  "$M<"+char(MSP_IDENT)+ "$M<"+char(MSP_STATUS)+ "$M<"+char(MSP_RAW_IMU)+ "$M<"+char(MSP_SERVO)+ "$M<"+char(MSP_MOTOR)
              + "$M<"+char(MSP_RC)+ "$M<"+char(MSP_RAW_GPS)+ "$M<"+char(MSP_COMP_GPS)+ "$M<"+char(MSP_ALTITUDE)+ "$M<"+char(MSP_BAT)
              + "$M<"+char(MSP_DEBUG);
      g_serial.write(outBuf);
      
      accROLL.addVal(ax);accPITCH.addVal(ay);accYAW.addVal(az);gyroROLL.addVal(gx);gyroPITCH.addVal(gy);gyroYAW.addVal(gz);
      magxData.addVal(magx);magyData.addVal(magy);magzData.addVal(magz);
      altData.addVal(alt);headData.addVal(head);
      debug1Data.addVal(debug1);debug2Data.addVal(debug2);debug3Data.addVal(debug3);debug4Data.addVal(debug4);

    }
    if ((time-time3)>20) {
      outBuf =  "$M<"+char(MSP_ATTITUDE);
      g_serial.write(outBuf);
      time3=time;
    }
    if (toggleReset) {
      toggleReset=false;
      toggleRead=true;
      outBuf =  "$M<"+char(MSP_RESET_CONF);
      g_serial.write(outBuf);
    }
    if (toggleRead) {
      toggleRead=false;
      outBuf =  "$M<"+char(MSP_RC_TUNING)+ "$M<"+char(MSP_PID)+ "$M<"+char(MSP_BOX)+ "$M<"+char(MSP_MISC);
      g_serial.write(outBuf);
      buttonWRITE.setColorBackground(green_);
    }
    if (toggleCalibAcc) {
      toggleCalibAcc=false;
      outBuf =  "$M<"+char(MSP_ACC_CALIBRATION);
      g_serial.write(outBuf);
    }
    if (toggleCalibMag) {
      toggleCalibMag=false;
      outBuf =  "$M<"+char(MSP_MAG_CALIBRATION);
      g_serial.write(outBuf);
    }
    if (toggleWrite) {
      toggleWrite=false;

      byteRC_RATE       = (round(confRC_RATE.value()*100));
      byteRC_EXPO       = (round(confRC_EXPO.value()*100));
      byteRollPitchRate = (round(rollPitchRate.value()*100));
      byteYawRate       = (round(yawRate.value()*100));
      byteDynThrPID     = (round(dynamic_THR_PID.value()*100));
      indTX=0;
      serialize8('$');serialize8('M');serialize8('<');serialize8(5);serialize8(MSP_SET_RC_TUNING);
      checksum=0;
      serialize8(byteRC_RATE);serialize8(byteRC_EXPO);serialize8(byteRollPitchRate);
      serialize8(byteYawRate);serialize8(byteDynThrPID);
      serialize8(checksum);
      for(i=0;i<indTX;i++) {g_serial.write(char(outBuf_[i]));}

      for(i=0;i<PIDITEMS;i++) {
        byteP[i] = (round(confP[i].value()*10));
        byteI[i] = (round(confI[i].value()*1000));
        byteD[i] = (round(confD[i].value()));
      }
      indTX=0;
      serialize8('$');serialize8('M');serialize8('<');serialize8(3*PIDITEMS);serialize8(MSP_SET_PID);
      checksum=0;
      for(i=0;i<PIDITEMS;i++) {serialize8(byteP[i]);serialize8(byteI[i]);serialize8(byteD[i]);}
      serialize8(checksum);
      for(i=0;i<indTX;i++) {g_serial.write(char(outBuf_[i]));}

      for(i=0;i<CHECKBOXITEMS;i++) {
        activation[i] = 0;
        for(aa=0;aa<6;aa++) {
          activation[i] += (int)(checkbox1[i].arrayValue()[aa]*(1<<aa)) + (int)(checkbox2[i].arrayValue()[aa]*(1<<(aa+6)));
        }
      }
      indTX=0;
      serialize8('$');serialize8('M');serialize8('<');serialize8(2*CHECKBOXITEMS);serialize8(MSP_SET_BOX);
      checksum=0;
      for(i=0;i<CHECKBOXITEMS;i++) {serialize16(activation[i]);}
      serialize8(checksum);
      for(i=0;i<indTX;i++) {g_serial.write(char(outBuf_[i]));}

      intPowerTrigger = (round(confPowerTrigger.value()));
      indTX=0;
      serialize8('$');serialize8('M');serialize8('<');serialize8(2);serialize8(MSP_SET_MISC);
      checksum=0;
      serialize16(intPowerTrigger);
      serialize8(checksum);
      for(i=0;i<indTX;i++) {g_serial.write(char(outBuf_[i]));}
      
      indTX=0;
      serialize8('$');serialize8('M');serialize8('<');serialize8(MSP_EEPROM_WRITE);
      for(i=0;i<indTX;i++) {g_serial.write(char(outBuf_[i]));}
    }

    while (g_serial.available()>0) {
      c = (g_serial.read());
      if (stateMSP > 99) {
        if (offset <= dataSize) {
          if (offset < dataSize) checksum ^= c;
          inBuf[offset++] = byte(c);
        } else {
          if ( checksum == inBuf[dataSize] ) {
            switch(stateMSP) {
              case MSP_IDENT:
                stateMSP = 0;
                version = read8();
                multiType = read8(); break;
              case MSP_STATUS:
                stateMSP = 0;
                cycleTime = read16();
                i2cError = read16();
                present = read16();
                mode = read16();
                if ((present&1) >0) {buttonAcc.setColorBackground(green_);} else {buttonAcc.setColorBackground(red_);}
                if ((present&2) >0) {buttonBaro.setColorBackground(green_);} else {buttonBaro.setColorBackground(red_);}
                if ((present&4) >0) {buttonMag.setColorBackground(green_);} else {buttonMag.setColorBackground(red_);}
                if ((present&8) >0) {buttonGPS.setColorBackground(green_);} else {buttonGPS.setColorBackground(red_);}
                if ((present&16)>0) {buttonSonar.setColorBackground(green_);} else {buttonSonar.setColorBackground(red_);}
                for(i=0;i<CHECKBOXITEMS;i++) {
                  if ((mode&(1<<i))>0) buttonCheckbox[i].setColorBackground(green_); else buttonCheckbox[i].setColorBackground(red_);
                } break;
              case MSP_RAW_IMU:
                stateMSP = 0;
                ax = read16();ay = read16();az = read16();
                gx = read16()/8;gy = read16()/8;gz = read16()/8;
                magx = read16()/3;magy = read16()/3;magz = read16()/3; break;
              case MSP_SERVO:
                stateMSP = 0;
                for(i=0;i<8;i++) servo[i] = read16(); break;
              case MSP_MOTOR:
                stateMSP = 0;
                for(i=0;i<8;i++) mot[i] = read16(); break;
              case MSP_RC:
                stateMSP = 0;
                rcRoll = read16();rcPitch = read16();rcYaw = read16();rcThrottle = read16();    
                rcAUX1 = read16();rcAUX2 = read16();rcAUX3 = read16();rcAUX4 = read16(); break;
              case MSP_RAW_GPS:
                stateMSP = 0;
                GPS_fix = read8();
                GPS_numSat = read8();
                GPS_latitude = read32();
                GPS_longitude = read32();
                GPS_altitude = read16();
                GPS_speed = read16(); break;
              case MSP_COMP_GPS:
                stateMSP = 0;
                GPS_distanceToHome = read16();
                GPS_directionToHome = read16();
                GPS_update = read8(); break;
              case MSP_ATTITUDE:
                stateMSP = 0;
                angx = read16()/10;angy = read16()/10;
                head = read16(); break;
              case MSP_ALTITUDE:
                stateMSP = 0;
                alt = read32(); break;
              case MSP_BAT:
                stateMSP = 0;
                bytevbat = read8();
                pMeterSum = read16(); break;
              case MSP_RC_TUNING:
                stateMSP = 0;
                byteRC_RATE = read8();byteRC_EXPO = read8();byteRollPitchRate = read8();
                byteYawRate = read8();byteDynThrPID = read8();
                confRC_RATE.setValue(byteRC_RATE/100.0);
                confRC_EXPO.setValue(byteRC_EXPO/100.0);
                rollPitchRate.setValue(byteRollPitchRate/100.0);
                yawRate.setValue(byteYawRate/100.0);
                dynamic_THR_PID.setValue(byteDynThrPID/100.0);
                confRC_RATE.setColorBackground(green_);confRC_EXPO.setColorBackground(green_);rollPitchRate.setColorBackground(green_);yawRate.setColorBackground(green_);dynamic_THR_PID.setColorBackground(green_); break;
              case MSP_ACC_CALIBRATION:
                stateMSP = 0; break;
              case MSP_MAG_CALIBRATION:
                stateMSP = 0; break;
              case MSP_PID:
                stateMSP = 0;
                for( i=0;i<PIDITEMS;i++) {
                  byteP[i] = read8();byteI[i] = read8();byteD[i] = read8();
                  confP[i].setValue(byteP[i]/10.0);confI[i].setValue(byteI[i]/1000.0);confD[i].setValue(byteD[i]);
                  confP[i].setColorBackground(green_);
                  confI[i].setColorBackground(green_);
                  confD[i].setColorBackground(green_);
                } break;
              case MSP_BOX:
                stateMSP = 0;
                for( i=0;i<CHECKBOXITEMS;i++) {
                  activation[i] = read16();
                  for( aa=0;aa<6;aa++) {
                    if ((activation[i]&(1<<aa))>0)     checkbox1[i].activate(aa); else checkbox1[i].deactivate(aa);
                    if ((activation[i]&(1<<(aa+6)))>0) checkbox2[i].activate(aa); else checkbox2[i].deactivate(aa);
                  }
                } break;
              case MSP_MISC:
                stateMSP = 0;
                intPowerTrigger = read16();
                confPowerTrigger.setValue(intPowerTrigger); break;
              case MSP_DEBUG:
                stateMSP = 0;
                debug1 = read16();debug2 = read16();debug3 = read16();debug4 = read16(); break;
            }
          }
          stateMSP = 0;
        }
      }

      if (stateMSP <5) {
        if (stateMSP == 4) {
          if (c > 99) {
            stateMSP = c;
            offset = 0;checksum = 0;p=0;
          } else {
            stateMSP = 0;
          } 
        }
        if (stateMSP == 3) {
          if (c<100) {
            stateMSP++;
            dataSize = c;
            if (dataSize>63) dataSize=63;
          } else {
            stateMSP = c;
          }
        }
        switch(c) {
          case '$':                                         //header detection $MW>
            if (stateMSP == 0) stateMSP++;break;
          case 'M':
            if (stateMSP == 1) stateMSP++;break;
          case '>':
            if (stateMSP == 2) stateMSP++;break;
        }
      }
    }
  }


  background(80);
  textFont(font15);
  text("multiwii.com",0,16);
  text("V",0,32);text(version, 10, 32);
  text(i2cError,xGraph+410,yGraph-10);
  text(cycleTime,xGraph+290,yGraph-10);

  text("GPS",480,245);

  text(GPS_altitude,530,260);
  text(GPS_latitude,530,275);
  text(GPS_latitude,530,290);
  text(GPS_speed,530,305);
  text(GPS_numSat,530,320);
  text(GPS_distanceToHome,630,260);


  textFont(font12);
  text("alt   :",480,260);
  text("lat   :",480,275);
  text("lon   :",480,290);
  text("speed :",480,305);
  text("sat   :",480,320);
  
  text("dist",590,245);
  text("home:",590,260);

  text("I2C error:",xGraph+350,yGraph-10);
  text("Cycle Time:",xGraph+220,yGraph-10);
  text("Power:",xGraph-5,yGraph-30); text(pMeterSum,xGraph+50,yGraph-30);
  text("pAlarm:",xGraph-5,yGraph-15);
  text("Volt:",xGraph-5,yGraph-2);  text(bytevbat/10.0,xGraph+50,yGraph-2);

  fill(255,255,255);

  axSlider.setValue(ax);aySlider.setValue(ay);azSlider.setValue(az);gxSlider.setValue(gx);gySlider.setValue(gy);gzSlider.setValue(gz);
  altSlider.setValue(alt/100);headSlider.setValue(head);magxSlider.setValue(magx);magySlider.setValue(magy);magzSlider.setValue(magz);
  debug1Slider.setValue(debug1/10);debug2Slider.setValue(debug2);debug3Slider.setValue(debug3);debug4Slider.setValue(debug4);

  for(i=0;i<8;i++) {
    motSlider[i].setValue(mot[i]);motSlider[i].hide();
    servoSliderH[i].setValue(servo[i]);servoSliderH[i].hide();
    servoSliderV[i].setValue(servo[i]);servoSliderV[i].hide();
  }

  rcStickThrottleSlider.setValue(rcThrottle);rcStickRollSlider.setValue(rcRoll);rcStickPitchSlider.setValue(rcPitch);rcStickYawSlider.setValue(rcYaw);
  rcStickAUX1Slider.setValue(rcAUX1);rcStickAUX2Slider.setValue(rcAUX2);rcStickAUX3Slider.setValue(rcAUX3);rcStickAUX4Slider.setValue(rcAUX4);

  stroke(255); 
  a=radians(angx);
  if (angy<-90) b=radians(-180 - angy);
  else if (angy>90) b=radians(+180 - angy);
  else b=radians(angy);
  h=radians(head);

  float size = 30.0;

  pushMatrix();
  camera(xObj,yObj,300/tan(PI*60.0/360.0),xObj/2+30,yObj/2-40,0,0,1,0);
  translate(xObj,yObj);
  directionalLight(200,200,200, 0, 0, -1);
  rotateZ(h);rotateX(b);rotateY(a);
  stroke(150,255,150);
  strokeWeight(0);sphere(size/3);strokeWeight(3);
  line(0,0, 10,0,-size-5,10);line(0,-size-5,10,+size/4,-size/2,10); line(0,-size-5,10,-size/4,-size/2,10);
  stroke(255);

  textFont(font12);
  if (multiType == 1) { //TRI
    ellipse(-size, -size, size, size);ellipse(+size, -size, size, size);ellipse(0,  +size,size, size);
    line(-size,-size, 0,0);line(+size,-size, 0,0);line(0,+size, 0,0);
    noLights();text(" TRICOPTER", -40,-50);camera();popMatrix();
 
    motSlider[0].setPosition(xMot+50,yMot+15);motSlider[0].setHeight(100);motSlider[0].setCaptionLabel("REAR");motSlider[0].show();
    motSlider[1].setPosition(xMot+100,yMot-15);motSlider[1].setHeight(100);motSlider[1].setCaptionLabel("RIGHT");motSlider[1].show();
    motSlider[2].setPosition(xMot,yMot-15);motSlider[2].setHeight(100);motSlider[2].setCaptionLabel("LEFT");motSlider[2].show();
    servoSliderH[5].setPosition(xMot,yMot+135);servoSliderH[5].setCaptionLabel("SERVO");servoSliderH[5].show(); 
  } else if (multiType == 2) { //QUAD+
    ellipse(0,  -size,   size,size);ellipse(0,  +size, size, size);ellipse(+size, 0,  size , size );ellipse(-size, 0,  size , size );
    line(-size,0, +size,0);line(0,-size, 0,+size);
    noLights();text("QUADRICOPTER +", -40,-50);camera();popMatrix();
    
    motSlider[0].setPosition(xMot+50,yMot+75);motSlider[0].setHeight(60);motSlider[0].setCaptionLabel("REAR");motSlider[0].show();
    motSlider[1].setPosition(xMot+100,yMot+35);motSlider[1].setHeight(60);motSlider[1].setCaptionLabel("RIGHT");motSlider[1].show();
    motSlider[2].setPosition(xMot,yMot+35);motSlider[2].setHeight(60);motSlider[2].setCaptionLabel("LEFT");motSlider[2].show();
    motSlider[3].setPosition(xMot+50,yMot-15);motSlider[3].setHeight(60);motSlider[3].setCaptionLabel("FRONT");motSlider[3].show();
  } else if (multiType == 3) { //QUAD X
    ellipse(-size,  -size, size, size);ellipse(+size,  -size, size, size);ellipse(-size,  +size, size, size);ellipse(+size,  +size, size, size);
    line(-size,-size, 0,0);line(+size,-size, 0,0);line(-size,+size, 0,0);line(+size,+size, 0,0);
    noLights();text("QUADRICOPTER X", -40,-50);camera();popMatrix();
    
    motSlider[0].setPosition(xMot+90,yMot+75);motSlider[0].setHeight(60);motSlider[0].setCaptionLabel("REAR_R");motSlider[0].show();
    motSlider[1].setPosition(xMot+90,yMot-15);motSlider[1].setHeight(60);motSlider[1].setCaptionLabel("FRONT_R");motSlider[1].show();
    motSlider[2].setPosition(xMot+10,yMot+75);motSlider[2].setHeight(60);motSlider[2].setCaptionLabel("REAR_L");motSlider[2].show();
    motSlider[3].setPosition(xMot+10,yMot-15);motSlider[3].setHeight(60);motSlider[3].setCaptionLabel("FRONT_L");motSlider[3].show(); 
  } else if (multiType == 4) { //BI
    ellipse(0-size,  0,   size, size);ellipse(0+size,  0,   size, size);
    line(0-size,0, 0,0);  line(0+size,0, 0,0);line(0,size*1.5, 0,0);
    noLights();text("BICOPTER", -30,-20);camera();popMatrix();
   
    motSlider[0].setPosition(xMot,yMot+30);motSlider[0].setHeight(55);motSlider[0].setCaptionLabel("");motSlider[0].show();
    motSlider[1].setPosition(xMot+100,yMot+30);motSlider[1].setHeight(55);motSlider[1].setCaptionLabel("");motSlider[1].show();
    servoSliderH[4].setPosition(xMot,yMot+100);servoSliderH[4].setWidth(60);servoSliderH[4].setCaptionLabel("");servoSliderH[4].show();
    servoSliderH[5].setPosition(xMot+80,yMot+100);servoSliderH[5].setWidth(60);servoSliderH[5].setCaptionLabel("");servoSliderH[5].show();
  } else if (multiType == 5) { //GIMBAL
    noLights();text("GIMBAL", -20,-10);camera();popMatrix();
    text("GIMBAL", xMot,yMot+25);
 
    servoSliderH[1].setPosition(xMot,yMot+75);servoSliderH[1].setCaptionLabel("ROLL");servoSliderH[1].show();
    servoSliderH[0].setPosition(xMot,yMot+35);servoSliderH[0].setCaptionLabel("PITCH");servoSliderH[0].show();
  } else if (multiType == 6) { //Y6
    ellipse(-size,-size,size,size);ellipse(size,-size,size,size);ellipse(0,-2+size,size,size);
    translate(0,0,7);
    ellipse(-5-size,-5-size,size,size);ellipse(5+size,-5-size,size,size);ellipse(0,3+size,size,size);
    line(-size,-size,0,0);line(+size,-size, 0,0);line(0,+size, 0,0);
    noLights();text("TRICOPTER Y6", -40,-55);camera();popMatrix();

    motSlider[0].setPosition(xMot+50,yMot+23);motSlider[0].setHeight(50);motSlider[0].setCaptionLabel("REAR");motSlider[0].show();
    motSlider[1].setPosition(xMot+100,yMot-18);motSlider[1].setHeight(50);motSlider[1].setCaptionLabel("RIGHT");motSlider[1].show();
    motSlider[2].setPosition(xMot,yMot-18);motSlider[2].setHeight(50);motSlider[2].setCaptionLabel("LEFT");motSlider[2].show();
    motSlider[3].setPosition(xMot+50,yMot+87);motSlider[3].setHeight(50);motSlider[3].setCaptionLabel("U_REAR");motSlider[3].show();
    motSlider[4].setPosition(xMot+100,yMot+48);motSlider[4].setHeight(50);motSlider[4].setCaptionLabel("U_RIGHT");motSlider[4].show();
    motSlider[5].setPosition(xMot,yMot+48);motSlider[5].setHeight(50);motSlider[5].setCaptionLabel("U_LEFT");motSlider[5].show();
  } else if (multiType == 7) { //HEX6
    ellipse(-size,-0.55*size,size,size);ellipse(size,-0.55*size,size,size);ellipse(-size,+0.55*size,size,size);
    ellipse(size,+0.55*size,size,size);ellipse(0,-size,size,size);ellipse(0,+size,size,size);
    line(-size,-0.55*size,0,0);line(size,-0.55*size,0,0);line(-size,+0.55*size,0,0);line(size,+0.55*size,0,0);line(0,+size,0,0);line(0,-size,0,0);
    noLights();text("HEXACOPTER", -40,-50);camera();popMatrix();

    motSlider[0].setPosition(xMot+90,yMot+65);motSlider[0].setHeight(50);motSlider[0].setCaptionLabel("REAR_R");motSlider[0].show();
    motSlider[1].setPosition(xMot+90,yMot-5);motSlider[1].setHeight(50);motSlider[1].setCaptionLabel("FRONT_R");motSlider[1].show();
    motSlider[2].setPosition(xMot+5,yMot+65);motSlider[2].setHeight(50);motSlider[2].setCaptionLabel("REAR_L");motSlider[2].show();
    motSlider[3].setPosition(xMot+5,yMot-5);motSlider[3].setHeight(50);motSlider[3].setCaptionLabel("FRONT_L");motSlider[3].show(); 
    motSlider[4].setPosition(xMot+50,yMot-20);motSlider[4].setHeight(50);motSlider[4].setCaptionLabel("FRONT");motSlider[4].show(); 
    motSlider[5].setPosition(xMot+50,yMot+90);motSlider[5].setHeight(50);motSlider[5].setCaptionLabel("REAR");motSlider[5].show(); 
  } else if (multiType == 8) { //FLYING_WING
    line(0,0, 1.8*size,size);line(1.8*size,size,1.8*size,size-30);  line(1.8*size,size-30,0,-1.5*size);
    line(0,0, -1.8*size,+size);line(-1.8*size,size,-1.8*size,+size-30);    line(-1.8*size,size-30,0,-1.5*size);
    noLights();text("FLYING WING", -40,-50);camera();popMatrix();

    servoSliderV[0].setPosition(xMot+5,yMot+10);servoSliderV[0].setCaptionLabel("LEFT");servoSliderV[0].show(); 
    servoSliderV[1].setPosition(xMot+100,yMot+10);servoSliderV[1].setCaptionLabel("RIGHT");servoSliderV[1].show();
    motSlider[0].setPosition(xMot+50,yMot+30);motSlider[0].setHeight(90);motSlider[0].setCaptionLabel("Mot");motSlider[0].show();
  } else if (multiType == 9) { //Y4
    ellipse(-size,  -size, size, size);ellipse(+size,  -size, size, size);ellipse(0,  +size, size+2, size+2);
    line(-size,-size, 0,0);line(+size,-size, 0,0);line(0,+size, 0,0);
    translate(0,0,7);
    ellipse(0,  +size, size, size);
    noLights();text("Y4", -5,-50);camera();popMatrix();
    
    motSlider[0].setPosition(xMot+80,yMot+75);motSlider[0].setHeight(60);motSlider[0].setCaptionLabel("REAR_1");motSlider[0].show();
    motSlider[1].setPosition(xMot+90,yMot-15);motSlider[1].setHeight(60);motSlider[1].setCaptionLabel("FRONT_R");motSlider[1].show();
    motSlider[2].setPosition(xMot+30,yMot+75);motSlider[2].setHeight(60);motSlider[2].setCaptionLabel("REAR_2");motSlider[2].show();
    motSlider[3].setPosition(xMot+10,yMot-15);motSlider[3].setHeight(60);motSlider[3].setCaptionLabel("FRONT_L");motSlider[3].show(); 
  } else if (multiType == 10) { //HEX6 X
    ellipse(-0.55*size,-size,size,size);ellipse(-0.55*size,size,size,size);ellipse(+0.55*size,-size,size,size);
    ellipse(+0.55*size,size,size,size);ellipse(-size,0,size,size);ellipse(+size,0,size,size);
    line(-0.55*size,-size,0,0);line(-0.55*size,size,0,0);line(+0.55*size,-size,0,0);line(+0.55*size,size,0,0);line(+size,0,0,0);  line(-size,0,0,0);
    noLights();text("HEXACOPTER X", -45,-50);camera();popMatrix();

    motSlider[0].setPosition(xMot+80,yMot+90);motSlider[0].setHeight(45);motSlider[0].setCaptionLabel("REAR_R");motSlider[0].show();
    motSlider[1].setPosition(xMot+80,yMot-20);motSlider[1].setHeight(45);motSlider[1].setCaptionLabel("FRONT_R");motSlider[1].show();
    motSlider[2].setPosition(xMot+25,yMot+90);motSlider[2].setHeight(45);motSlider[2].setCaptionLabel("REAR_L");motSlider[2].show();
    motSlider[3].setPosition(xMot+25,yMot-20);motSlider[3].setHeight(45);motSlider[3].setCaptionLabel("FRONT_L");motSlider[3].show(); 
    motSlider[4].setPosition(xMot+90,yMot+35);motSlider[4].setHeight(45);motSlider[4].setCaptionLabel("RIGHT");motSlider[4].show(); 
    motSlider[5].setPosition(xMot+5,yMot+35);motSlider[5].setHeight(45);motSlider[5].setCaptionLabel("LEFT");motSlider[5].show(); 
  } else if (multiType >= 11 && multiType <= 13) { //OCTOX8
    // GUI is the same for all 8 motor configs. multiType 11-13
    noLights();text("OCTOCOPTER X8", -45,-50);camera();popMatrix();
  } else if (multiType == 14) { //AIRPLANE
    float Span = size*1.3;  
    float VingRoot = Span*0.25;  
    // Wing
    line(0,0,  Span,0);   line(Span,0, Span, VingRoot);       line(Span, VingRoot, 0,VingRoot); 
    line(0,0,  -Span,0);   line(-Span,0, -Span, VingRoot);       line(-Span, VingRoot, 0,VingRoot);    
    // Stab
    line(-(size*0.4),size,  (size*0.4),size);   line(-(size*0.4),size+5,  (size*0.4),size+5); 
    line(-(size*0.4),size,  -(size*0.4),size+5);      line((size*0.4),size,  (size*0.4),size+5);     
    // Body  
    line(-2,size,  -2,-size+5); line(2,size,  2,-size+5); line( -2,-size+5,  2,-size+5);    
    // Fin 
    line(0,size-3,0,  0,size,15); line(0,size,15,  0,size+5,15);line(0,size+5,15,  0,size+5,0);       
    noLights();
    textFont(font12);
    text("AIRPLANE", -40,-50);camera();popMatrix();
  
    servoSliderH[3].setPosition(xMot,yMot-5) ;servoSliderH[3].setCaptionLabel("Wing 1");servoSliderH[3].show();
    servoSliderH[4].setPosition(xMot,yMot+25);servoSliderH[4].setCaptionLabel("Wing 2");servoSliderH[4].show();
    servoSliderH[5].setPosition(xMot,yMot+55);servoSliderH[5].setCaptionLabel("Rudd");servoSliderH[5].show();
    servoSliderH[6].setPosition(xMot,yMot+85);servoSliderH[6].setCaptionLabel("Elev");servoSliderH[6].show();
    servoSliderH[7].setPosition(xMot,yMot+115);servoSliderH[7].setCaptionLabel("Thro");servoSliderH[7].show();    
    
    motSlider[0].hide();motSlider[1].hide();motSlider[2].hide();motSlider[3].hide();motSlider[4].hide();motSlider[5].hide();
    servoSliderH[1].hide();servoSliderH[2].hide();
  }else if (multiType == 15) { //Heli 120 
    // HeliGraphics    
    float scalesize=size*0.8;
    // Rotor
    ellipse(0, 0, 2*scalesize, 2*scalesize);
    // Body  
    line(0,1.5*scalesize,  -2,-0.5*scalesize); line(0,1.5*scalesize,  2,-0.5*scalesize); line( -2,-0.5*scalesize,  2,-0.5*scalesize);    
    // Fin 
    float finpos = scalesize * 1.3;
    int HFin=5;
    int LFin=10;  
    line(0,finpos-3,0,  0,finpos+7,-LFin); line(0,finpos+7,-LFin,  0,finpos+10,-LFin);line(0,finpos+10,-LFin,  0,finpos+5,0); 
    line(0,finpos-3,0,  0,finpos,HFin); line(0,finpos,HFin,  0,finpos+5,HFin);line(0,finpos+5,HFin,  0,finpos+5,0); 
 
    // Stab
    line(-(scalesize*0.3),scalesize,  (scalesize*0.3),scalesize);   line(-(scalesize*0.3),scalesize+3, (scalesize*0.3),scalesize+3); 
    line(-(scalesize*0.3),scalesize, -(scalesize*0.3),scalesize+3); line((scalesize*0.3),scalesize,    (scalesize*0.3),scalesize+3);  
   
    noLights();
    textFont(font12);
    text("Heli 120 CCPM", -42,-50);camera();popMatrix();
	
    // Sliders
    servoSliderH[3].setPosition(xMot,yMot-5) ;servoSliderH[3].setCaptionLabel("Nick");servoSliderH[3].show();
    servoSliderH[4].setPosition(xMot,yMot+25);servoSliderH[4].setCaptionLabel("Left");servoSliderH[4].show();
    servoSliderH[5].setPosition(xMot,yMot+55);servoSliderH[5].setCaptionLabel("Yaw");servoSliderH[5].show();
    servoSliderH[6].setPosition(xMot,yMot+85);servoSliderH[6].setCaptionLabel("Right");servoSliderH[6].show();
    servoSliderH[7].setPosition(xMot,yMot+115);servoSliderH[7].setCaptionLabel("Thro");servoSliderH[7].show();  
  } else if (multiType == 16) { //Heli 90 
    // HeliGraphics    
    float scalesize=size*0.8;
    // Rotor
    ellipse(0, 0, 2*scalesize, 2*scalesize);
    // Body  
    line(0,1.5*scalesize,  -2,-0.5*scalesize); line(0,1.5*scalesize,  2,-0.5*scalesize); line( -2,-0.5*scalesize,  2,-0.5*scalesize);    
    // Fin 
    float finpos = scalesize * 1.3;
    int HFin=5;
    int LFin=10;  
    line(0,finpos-3,0,  0,finpos+7,-LFin); line(0,finpos+7,-LFin,  0,finpos+10,-LFin);line(0,finpos+10,-LFin,  0,finpos+5,0); 
    line(0,finpos-3,0,  0,finpos,HFin); line(0,finpos,HFin,  0,finpos+5,HFin);line(0,finpos+5,HFin,  0,finpos+5,0); 
 
     // Stab
    line(-(scalesize*0.3),scalesize,  (scalesize*0.3),scalesize);   line(-(scalesize*0.3),scalesize+3, (scalesize*0.3),scalesize+3); 
    line(-(scalesize*0.3),scalesize, -(scalesize*0.3),scalesize+3); line((scalesize*0.3),scalesize,    (scalesize*0.3),scalesize+3);  
 
    noLights();
    textFont(font12);
    text("Heli 90", -16,-50);camera();popMatrix();
	
    // Sliders
    servoSliderH[3].setPosition(xMot,yMot-5) ;servoSliderH[3].setCaptionLabel("NICK");servoSliderH[3].show();
    servoSliderH[4].setPosition(xMot,yMot+25);servoSliderH[4].setCaptionLabel("ROLL");servoSliderH[4].show();
    servoSliderH[5].setPosition(xMot,yMot+55);servoSliderH[5].setCaptionLabel("YAW");servoSliderH[5].show();
    servoSliderH[6].setPosition(xMot,yMot+85);servoSliderH[6].setCaptionLabel("COLL");servoSliderH[6].show();
    servoSliderH[7].setPosition(xMot,yMot+115);servoSliderH[7].setCaptionLabel("THRO");servoSliderH[7].show();  
  }  else if (multiType == 17) { //Vtail   
    ellipse(-0.55*size,size,size,size); ellipse(+0.55*size,size,size,size);
    line(-0.55*size,size,0,0);line(+0.55*size,size,0,0);    
    ellipse(-size, -size, size, size);ellipse(+size, -size, size, size);
    line(-size,-size, 0,0); line(+size,-size, 0,0);  
    noLights();
    textFont(font12);
    text("Vtail", -10,-50);camera();popMatrix();
    motSlider[0].setPosition(xMot+80,yMot+70 );motSlider[0].setHeight(60);motSlider[0].setCaptionLabel("REAR_R");motSlider[0].show();
    motSlider[1].setPosition(xMot+100,yMot-15);motSlider[1].setHeight(60);motSlider[1].setCaptionLabel("RIGHT" );motSlider[1].show();
    motSlider[2].setPosition(xMot+25,yMot+70 );motSlider[2].setHeight(60);motSlider[2].setCaptionLabel("REAR_L");motSlider[2].show();
    motSlider[3].setPosition(xMot+2,yMot-15  );motSlider[3].setHeight(60);motSlider[3].setCaptionLabel("LEFT"  );motSlider[3].show(); 
    
    motSlider[4].hide();motSlider[5].hide();
    servoSliderH[1].hide();servoSliderH[2].hide();servoSliderH[3].hide();servoSliderH[4].hide();
    servoSliderV[0].hide();servoSliderV[1].hide();servoSliderV[2].hide();
  } else {
    noLights();camera();popMatrix();
  }
  
  pushMatrix();
  translate(xObj+60,yObj-165);
  rotate(a);
  textFont(font15);text("ROLL", -20, 15);
  line(-30,0,+30,0);line(0,0,0,-10);
  popMatrix();
  
  pushMatrix();
  translate(xObj+60,yObj-100);
  rotate(b);
  textFont(font15);text("PITCH", -30, 15);
  line(-30,0,30,0);line(+30,0,30-size/3 ,size/3);line(+30,0,30-size/3 ,-size/3);  
  popMatrix();
 
  pushMatrix();
  translate(xObj-20,yObj-133);

  size=15;
  strokeWeight(1.5);
  if (GPS_update == 1) {
    fill(125);stroke(125);
  } else {
    fill(160);stroke(160);
  }
  ellipse(0,  0,   4*size+7, 4*size+7);

  rotate(GPS_directionToHome*PI/180);
  strokeWeight(4);stroke(200);line(0,0, 0,-3*size);line(0,-3*size, -5 ,-3*size+10); line(0,-3*size, +5 ,-3*size+10);  
  rotate(-GPS_directionToHome*PI/180);

  strokeWeight(1.5);fill(0);stroke(0);ellipse(0,  0,   2*size+7, 2*size+7);

  stroke(255);

  rotate(head*PI/180);
  line(0,size, 0,-size); line(0,-size, -5 ,-size+10); line(0,-size, +5 ,-size+10);
  popMatrix();
  text("N",xObj-25,yObj-155);text("S",xObj-25,yObj-100);
  text("W",xObj-53,yObj-127);text("E",xObj   ,yObj-127);

  strokeWeight(1);
  fill(255, 255, 255);
  g_graph.drawGraphBox();
  
  strokeWeight(1.5);
  stroke(255, 0, 0); if (axGraph) g_graph.drawLine(accROLL, -1000, +1000);
  stroke(0, 255, 0); if (ayGraph) g_graph.drawLine(accPITCH, -1000, +1000);
  stroke(0, 0, 255);
  if (azGraph) {
    if (scaleSlider.value()<2) g_graph.drawLine(accYAW, -1000, +1000);
    else g_graph.drawLine(accYAW, 200*scaleSlider.value()-1000,200*scaleSlider.value()+500);
  }
  
  float altMin = (altData.getMinVal() + altData.getRange() / 2) - 100;
  float altMax = (altData.getMaxVal() + altData.getRange() / 2) + 100;

  stroke(200, 200, 0);  if (gxGraph)   g_graph.drawLine(gyroROLL, -300, +300);
  stroke(0, 255, 255);  if (gyGraph)   g_graph.drawLine(gyroPITCH, -300, +300);
  stroke(255, 0, 255);  if (gzGraph)   g_graph.drawLine(gyroYAW, -300, +300);
  stroke(125, 125, 125);if (altGraph) g_graph.drawLine(altData, altMin, altMax);
  stroke(225, 225, 125);if (headGraph)  g_graph.drawLine(headData, -370, +370);
  stroke(50, 100, 150); if (magxGraph) g_graph.drawLine(magxData, -500, +500);
  stroke(100, 50, 150); if (magyGraph) g_graph.drawLine(magyData, -500, +500);
  stroke(150, 100, 50); if (magzGraph) g_graph.drawLine(magzData, -500, +500);

  stroke(0, 0, 0);
  if (debug1Graph)  g_graph.drawLine(debug1Data, -5000, +5000);
  if (debug2Graph)  g_graph.drawLine(debug2Data, -5000, +5000);
  if (debug3Graph)  g_graph.drawLine(debug3Data, -5000, +5000);
  if (debug4Graph)  g_graph.drawLine(debug4Data, -5000, +5000);

  fill(0, 0, 0);

  strokeWeight(3);stroke(0);
  rectMode(CORNERS);
  rect(xMot-5,yMot-20, xMot+145, yMot+150);
  rect(xRC-5,yRC-5, xRC+185, yRC+210);
  rect(xParam,yParam, xParam+355, yParam+280);

  int xSens       = xParam + 80;
  int ySens       = yParam + 210;
  stroke(255);
  a=min(confRC_RATE.value(),1);
  b=confRC_EXPO.value();
  strokeWeight(1);
  line(xSens,ySens,xSens,ySens+40);
  line(xSens,ySens+40,xSens+70,ySens+40);
  strokeWeight(3);stroke(30,120,30);
  for(i=0;i<70;i++) {
    inter = 10*i;
    val = a*inter*(1-b+inter*inter*b/490000);
    point(xSens+i,ySens+(70-val/10)*4/7);
  }
  if (confRC_RATE.value()>1) { 
    stroke(220,100,100);
    ellipse(xSens+70, ySens, 7, 7);
  }
  
  fill(255);
  textFont(font15);    
  text("P",xParam+45,yParam+15);text("I",xParam+90,yParam+15);text("D",xParam+130,yParam+15);
  textFont(font12);
  text("    RC",xParam+3,yParam+220);
  text("RATE",xParam+3,yParam+232);
  text("EXPO",xParam+3,yParam+250);
  text("RATE",xParam+160,yParam+15);
  text("ROLL",xParam+3,yParam+32);text("PITCH",xParam+3,yParam+52);text("YAW",xParam+3,yParam+72);
  text("ALT",xParam+3,yParam+92);
  text("VEL",xParam+3,yParam+112);
  text("GPS",xParam+3,yParam+132);
  text("LEVEL",xParam+1,yParam+152);
  text("MAG",xParam+3,yParam+172); 
  text("Throttle PID",xParam+220,yParam+15);text("attenuation",xParam+220,yParam+30);
  text("AUX1",xBox+55,yBox+5);text("AUX2",xBox+105,yBox+5);
  textFont(font8);
  text("LOW",xBox+37,yBox+15);text("MID",xBox+57,yBox+15);text("HIGH",xBox+74,yBox+15);
  text("LOW",xBox+100,yBox+15);text("MID",xBox+123,yBox+15);text("HIGH",xBox+140,yBox+15);

  pushMatrix();
  translate(0,0,0);
  if (mouseX>xBox && mouseX<xBox+325 && mouseY>yBox && mouseY<yBox+190) {
    stroke(0);
    fill(0);
    rect(xBox+150,yBox-5,xBox+325, yBox+190);
    stroke(255);fill(255);

    textFont(font12);
    text("AUX3",xBox+180,yBox+5);text("AUX4",xBox+235,yBox+5);
    textFont(font8);
    text("LOW",xBox+37+130,yBox+15);text("MID",xBox+57+130,yBox+15);text("HIGH",xBox+74+130,yBox+15);
    text("LOW",xBox+100+130,yBox+15);text("MID",xBox+123+130,yBox+15);text("HIGH",xBox+140+130,yBox+15);

    for(i=0;i<CHECKBOXITEMS;i++) {
      checkbox2[i].show();
    }
    for(i=0;i<8;i++) {
      motSlider[i].hide();
      servoSliderH[i].hide();
      servoSliderV[i].hide();
    }
    buttonAcc.hide();buttonBaro.hide();buttonMag.hide();buttonGPS.hide();buttonSonar.hide();buttonOptic.hide();
  } else {
    for( i=0;i<CHECKBOXITEMS;i++) {
      checkbox2[i].hide();
    }
    buttonAcc.show();buttonBaro.show();buttonMag.show();buttonGPS.show();buttonSonar.show();buttonOptic.show();
  }
  popMatrix();
  if (versionMisMatch == 1) {textFont(font15);fill(#000000);text("GUI vs. Arduino: Version or Buffer size mismatch",180,420); return;}
}

void ACC_ROLL(boolean theFlag) {axGraph = theFlag;}
void ACC_PITCH(boolean theFlag) {ayGraph = theFlag;}
void ACC_Z(boolean theFlag) {azGraph = theFlag;}
void GYRO_ROLL(boolean theFlag) {gxGraph = theFlag;}
void GYRO_PITCH(boolean theFlag) {gyGraph = theFlag;}
void GYRO_YAW(boolean theFlag) {gzGraph = theFlag;}
void ALT(boolean theFlag) {altGraph = theFlag;}
void HEAD(boolean theFlag) {headGraph = theFlag;}
void MAGX(boolean theFlag) {magxGraph = theFlag;}
void MAGY(boolean theFlag) {magyGraph = theFlag;}
void MAGZ(boolean theFlag) {magzGraph = theFlag;}
void DEBUG1(boolean theFlag) {debug1Graph = theFlag;}
void DEBUG2(boolean theFlag) {debug2Graph = theFlag;}
void DEBUG3(boolean theFlag) {debug3Graph = theFlag;}
void DEBUG4(boolean theFlag) {debug4Graph = theFlag;}

public void controlEvent(ControlEvent theEvent) {
  if (theEvent.isGroup()) if (theEvent.name()=="portComList") InitSerial(theEvent.group().value()); // initialize the serial port selected
}

public void bSTART() {
  if(graphEnable == false) {return;}
  graph_on=1;
  toggleRead=true;
  g_serial.clear();
}

public void bSTOP() {
  graph_on=0;
}

public void READ() {
  toggleRead = true;
}

public void RESET() {
  toggleReset = true;
}

public void WRITE() {
  toggleWrite = true;
}

public void CALIB_ACC() {
  toggleCalibAcc = true;
}
public void CALIB_MAG() {
  toggleCalibMag = true;
}

// initialize the serial port selected in the listBox
void InitSerial(float portValue) {
  if (portValue < commListMax) {
    String portPos = Serial.list()[int(portValue)];
    txtlblWhichcom.setValue("COM = " + shortifyPortName(portPos, 8));
    g_serial = new Serial(this, portPos, 115200);
    init_com=1;
    buttonSTART.setColorBackground(green_);buttonSTOP.setColorBackground(green_);buttonREAD.setColorBackground(green_);
    buttonRESET.setColorBackground(green_);commListbox.setColorBackground(green_);
    buttonCALIBRATE_ACC.setColorBackground(green_); buttonCALIBRATE_MAG.setColorBackground(green_);
    graphEnable = true;
    g_serial.buffer(256);
  } else {
    txtlblWhichcom.setValue("Comm Closed");
    init_com=0;
    buttonSTART.setColorBackground(red_);buttonSTOP.setColorBackground(red_);commListbox.setColorBackground(red_);
    graphEnable = false;
    init_com=0;
    g_serial.stop();
  }
}

//********************************************************
//********************************************************
//********************************************************

class cDataArray {
  float[] m_data;
  int m_maxSize, m_startIndex = 0, m_endIndex = 0, m_curSize;
  
  cDataArray(int maxSize){
    m_maxSize = maxSize;
    m_data = new float[maxSize];
  }
  void addVal(float val) {
    m_data[m_endIndex] = val;
    m_endIndex = (m_endIndex+1)%m_maxSize;
    if (m_curSize == m_maxSize) {
      m_startIndex = (m_startIndex+1)%m_maxSize;
    } else {
      m_curSize++;
    }
  }
  float getVal(int index) {return m_data[(m_startIndex+index)%m_maxSize];}
  int getCurSize(){return m_curSize;}
  int getMaxSize() {return m_maxSize;}
  float getMaxVal() {
    float res = 0.0;
    for(int i=0; i<m_curSize-1; i++) if ((m_data[i] > res) || (i==0)) res = m_data[i];
    return res;
  }
  float getMinVal() {
    float res = 0.0;
    for(int i=0; i<m_curSize-1; i++) if ((m_data[i] < res) || (i==0)) res = m_data[i];
    return res;
  }
  float getRange() {return getMaxVal() - getMinVal();}
}

// This class takes the data and helps graph it
class cGraph {
  float m_gWidth, m_gHeight, m_gLeft, m_gBottom, m_gRight, m_gTop;
  
  cGraph(float x, float y, float w, float h) {
    m_gWidth     = w; m_gHeight    = h;
    m_gLeft      = x; m_gBottom    = y;
    m_gRight     = x + w;
    m_gTop       = y + h;
  }
  
  void drawGraphBox() {
    stroke(0, 0, 0);
    rectMode(CORNERS);
    rect(m_gLeft, m_gBottom, m_gRight, m_gTop);
  }
  
  void drawLine(cDataArray data, float minRange, float maxRange) {
    float graphMultX = m_gWidth/data.getMaxSize();
    float graphMultY = m_gHeight/(maxRange-minRange);
    
    for(int i=0; i<data.getCurSize()-1; ++i) {
      float x0 = i*graphMultX+m_gLeft;
      float y0 = m_gTop-(((data.getVal(i)-(maxRange+minRange)/2)*scaleSlider.value()+(maxRange-minRange)/2)*graphMultY);
      float x1 = (i+1)*graphMultX+m_gLeft;
      float y1 = m_gTop-(((data.getVal(i+1)-(maxRange+minRange)/2 )*scaleSlider.value()+(maxRange-minRange)/2)*graphMultY);
      line(x0, y0, x1, y1);
    }
  }
}
