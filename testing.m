

METAKR = 'planetsorbitskernels.txt';

cspice_furnsh ( METAKR );

planets_name_for_struct = {'EARTH','SUN','MOON','JUPITER','VENUS','MARS','SATURN';'EARTH','SUN','301','5','VENUS','4','6'};
observer = 'EARTH';% or 339

global G;
G = 6.673e-20;
global L2frame;
L2frame = true;



time1 = '2030 MAY 22 00:03:19.126';
time2 = '2030 NOV 21 09:06:53.955';

et = cspice_str2et(time1);
xform = cspice_sxform('J2000','L2CENTERED', et);


%2030-05-22T00:03:19.126  -5.618445118318512e+005  -1.023778587192635e+006  -1.522315532439711e+005   5.343825699573794e-001  -2.686719669693540e-001  -1.145921728828306e-001
% after the insertion maneuver
%2030-05-22T00:03:19.126  -5.618445118318512e+005  -1.023778587192635e+006  -1.522315532439711e+005   5.457150405565953e-001  -2.882041405454675e-001  -1.021163220453542e-001

% state at time1 before maneuver
state1 = [-5.618445118318512e+005;  -1.023778587192635e+006;  -1.522315532439711e+005;...
    5.343825699573794e-001;  -2.686719669693540e-001;  -1.145921728828306e-001];
astate1 = [-5.618445118318512e+005;  -1.023778587192635e+006;  -1.522315532439711e+005;...
    5.457150405565953e-001;  -2.882041405454675e-001;  -1.021163220453542e-001];

% state at time2 before maneuver
state2 = [5.792164079660024e+005;   7.745493863637365e+005;   6.153406974786045e+005;...
    -5.399272545222726e-001;   2.861191946127703e-001;   1.254733378780861e-001];

l2 = xform*astate1;

disp(l2);



