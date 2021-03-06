
clc
clear all
%close all

%% Define local variables
METAKR = 'planetsorbitskernels.txt';%'satelliteorbitkernels.txt';

%% Settings
full_mission = false; % full mission or just a test part before the first maneuver
one_revolution = false; % only one maneuver applied % if false then all mission till the end
starting_from_earth = false; % mission with leop phase. Leave it false always!
RKV_89 = true;
    simpleRKV89 = false; % leave it false better
    embedded_estimation = true;
ABM = false;
RK45 = false;
PD78 = false;
apply_maneuvers = false;
check_energy = false;
reverse_check = false;
check_with_the_reference = false;
global L2frame;
L2frame = true;


global checkrkv89;
global checkrkv89_emb;
global checkabm;
global checkrk;
global checkpd78;

% initially set to false. Changes automatically to true below in the next if statement

checkrkv89 = false;
checkrkv89_emb = false;
checkabm = false;
checkrk = false;
checkpd78 = false;


if not(full_mission)
    load('irassihalotime.mat', 'Date');
    load('irassihalogmat.mat', 'Gmat');
       
else
    load('IRASSIFullMissionDate.mat', 'Date');
    load('IRASSIFullMission.mat', 'Gmat');
end


%% Load kernel
cspice_furnsh ( METAKR );
planets_name_for_struct = {'EARTH','SUN','MOON','JUPITER','VENUS','MARS','SATURN';'EARTH','SUN','301','5','VENUS','4','6'};
observer = 'EARTH';% or 339

% global G;
% G = 6.67e-20; % km % or -17
global G;
G = 6.673e-20;

%% Ephemeris from SPICE
% Define initial epoch for a satellite
initial_utctime = '2030 MAY 22 00:03:25.693'; 
end_utctime = '2030 NOV 21 11:22:23.659';
initial_et = cspice_str2et ( initial_utctime );
end_et = cspice_str2et ( end_utctime );
ABMstep = 2700; 

abm_et_vector = initial_et:ABMstep:end_et;

if not(full_mission)
   et_vector = zeros(1,length(Date));
   for d=1:length(Date)
        utcdate = datestr((datetime(Date(d,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC')), 'yyyy mmm dd HH:MM:SS.FFF');
        et_vector(d) = cspice_str2et (utcdate);
   end
else
    if one_revolution == true
        et_vector = zeros(1,12255);
        for d=3245:1:15500-1
        utcdate = datestr((datetime(Date(d,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC')), 'yyyy mmm dd HH:MM:SS.FFF');
        et_vector(d-3244) = cspice_str2et (utcdate);
        end
    else
        if ~starting_from_earth
            et_vector = zeros(1,length(Date));
            for d=3245:length(Date)
            utcdate = datestr((datetime(Date(d,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC')), 'yyyy mmm dd HH:MM:SS.FFF');
            et_vector(d-3244) = cspice_str2et (utcdate);
            end
        else
            et_vector = zeros(1,length(Date));
            for d=1:length(Date)
            utcdate = datestr((datetime(Date(d,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC')), 'yyyy mmm dd HH:MM:SS.FFF');
            et_vector(d) = cspice_str2et (utcdate);
            end
        end
    end
end


%Transform GMAT checking data to L2 frame
if L2frame == true
   Gmat = EcenToL2frame(Gmat, et_vector);    
end


%% Setting up some values and structures
% Satellite initial position w.r.t the Earth center
%initial_state = [-561844.307770134;-1023781.19884100;-152232.354717768;0.545714129191316;-0.288204299060291;-0.102116477725135]; 
initial_state =  [-5.618445118318512e+005;  -1.023778587192635e+006;  -1.522315532439711e+005;   5.343825699573794e-001;  -2.686719669693540e-001;  -1.145921728828306e-001];
sat = create_sat_structure(initial_state);
% Get initial states for calculating initial energy
[earth_init, sun_init, moon_init, jupiter_init, venus_init, mars_init, saturn_init] = create_structure( planets_name_for_struct, initial_et, observer);



%% Check influences
global influence;
influence = zeros(3,2);


%% INTEGRATION PART
options = odeset('RelTol',1e-12,'AbsTol',1e-12);

% ODE45
if RK45 == true
tic
orbit = ode45(@(t,y) force_model(t,y),et_vector,initial_state,options);    
if check_with_the_reference == true
   % RK_last_point_difference = orbit.y(:,length(orbit.y)) - Gmat(:,length(Gmat));
end
toc

if L2frame == true
    rk_orbitL2 = EcenToL2frame(orbit.y, orbit.x);
    RK_last_point_difference = rk_orbitL2(:,length(rk_orbitL2)) - Gmat(:,length(Gmat));
end

end

% Adams-Bashforth-Moulton Predictor-Corrector
if ABM == true
tic 
[orbit_ab8, tour] = adambashforth8(@force_model,abm_et_vector,initial_state, length(abm_et_vector));
if check_with_the_reference == true
    ABM_last_point_difference = orbit_ab8(:,length(orbit_ab8)) - Gmat(:,length(Gmat));
end
toc

if L2frame == true
    orbit_ab8 = EcenToL2frame(orbit_ab8, abm_et_vector);
end


end

% Runge-Kutta-Verner 8(9)

tic

if RKV_89 == true
    
    if simpleRKV89 == true
       %[orbit_rkv89, tourrkv] = RKV89(@force_model,et_vector,initial_state, length(et_vector));
       [orbit_rkv89, tourrkv] = RKV89_2(@force_model,et_vector,initial_state, length(et_vector));
       if check_with_the_reference == true
          RKV89_last_point_difference = orbit_rkv89(:,length(orbit_rkv89)) - Gmat(:,length(Gmat));
       end
       
%        if temp_L2frame == true
%             rkv89_orbitL2 = EcenTotemp_L2frame(orbit_rkv89, et_vector);
%        end

       
    end
    if embedded_estimation == true
        
        totalorbit_rkv89 = [];
        totalepochs_rkv89 = [];
        final_point = 10.747744831378550e+08; % The integrator should not reach it.
        
        complete = false;
        init_t = 958.910668311133e+006;%et_vector(1);
        init_state = initial_state;
        
        % Use DefineManeuver script in order to define maneuvers
        % Maneuver 22 May 2030, applied to reach y vx vz = 0 after 3 months
        % With this maneuver init state becomes:
        % [-5.618445118318512e+05; -1.023778587192635e+06;
        % -1.522315532439711e+05; 0.547639025551028; -0.284888483477083;
        % -0.110550570310552]
        % last point at 9.669336468097067e+08
        % [2.001588983506205e+05;-3.190871211700141e-06;-3.630246968234776e+05;
        % -6.168121569061213e-13; -0.341774009105191;
        % 4.510419815417777e-13];
        dV1 = [0.013256455593648; -0.016216516507728; 0.004041602572279]; % 3 months!
        %dV1 = [0.011451409903010; -0.019400946449742; 0.012175651186894]; % 6 months!
        % Maneuver at time 9.669336468097093e+08;
        % Init state becomes: [1.485359168304580e+06;  -6.574308768747580e+05; -6.807000270951350e+05];  
        % v = [-0.018542360305139;0.001079211439632; -0.008706857622573];
        dV2 = [-7.803777280688135e-04; 0.001854569833090;-0.007247538179753]; 
        dV3 = [0.002544242144491; -0.002921527856874; 0.007703415162441];
        dV4 = [-0.001625936670348; -0.003125208256016; -0.008088501084076];
        dV5 = [-0.002918536114165;-0.003384664726700;0.008333531253574];
        dV6 = [-0.002355831016669;-0.002402859984804;-0.008729136657509];
        deltaVs = {dV1;dV2;dV3;dV4;dV5;dV6};
        
        maneuver_number = 1;
        n_integrations = 6;
        n = 1;
        while ~complete
            
            maneuver = deltaVs{maneuver_number};
            init_state(1:6) = init_state(1:6) + [0;0;0;maneuver(1);maneuver(2);maneuver(3)];
            phi0 = reshape(eye(6), 36, 1);
            init_state = [init_state(1:6); phi0];
            
            
            %[epochs, orbit_rkv89_emb, lastState_E] = rkv89emb(@force_model, [init_t final_point], init_state);
            [epochs, y0state, orbit_rkv89_emb, y0state_E] = rkv89emb_maneuvers(@simplified_force_model_srp, init_t , init_state);

            totalorbit_rkv89 = [totalorbit_rkv89, orbit_rkv89_emb];
            totalepochs_rkv89 = [totalepochs_rkv89, epochs];
            
            
            % Change the values for the next orbit part integration
            init_t = epochs(end);
            init_state = y0state_E;
            
            maneuver_number = maneuver_number + 1;
            
            n = n+1;
            if n > n_integrations 
               complete = true; 
            end
            
        end
        
        
        % For plotting
        orbit_rkv89_emb = totalorbit_rkv89;

                
    end
end
toc

% Prince Dormand 7(8)
if PD78 == true
    options87 = odeset('RelTol',1e-13,'AbsTol',1e-13, 'MaxStep',2700,'InitialStep',60);
    orbit_ode87 = zeros(6, length(et_vector));
    orbit_ode87(:,1) = initial_state;
    [pd78_et_vector, orbit_ode87] = ode87(@(t,y) force_model(t,y),[et_vector(1) et_vector(5879)], orbit_ode87(:,1), options87);
    orbit_ode87 = orbit_ode87';
    pd78_et_vector = pd78_et_vector';

if check_with_the_reference == true
   PD78_last_point_difference = orbit_ode87(:,length(orbit_ode87)) - Gmat(:,length(Gmat));
end

%  if temp_L2frame == true
%      pd78_orbitL2 = EcenTotemp_L2frame(orbit_ode87, pd78_et_vector);
%  end


end

%% Table with resulting distance from the reference at the last point
 % Create a table with results
 if check_with_the_reference == true
    Integrators = {'RKV89';'ABM';'RK45';'PD78';'RKV89_embedded'};
    
    if RKV_89 && ~simpleRKV89
         RKV89_last_point_difference = zeros(6,1);
        if ~embedded_estimation
            RKV89_emb_last_point_difference = zeros(6,1);
       end
    end
    if ~RKV_89 
        RKV89_last_point_difference = zeros(6,1);
        RKV89_emb_last_point_difference = zeros(6,1);
    end
    if ~ABM
        ABM_last_point_difference = zeros(6,1);
    end
    if ~RK45 
        RK_last_point_difference = zeros(6,1);
    end
    if ~PD78 
        PD78_last_point_difference = zeros(6,1);
    end
    %x_diffs = [rkv89_initial_value_difference;abm_initial_value_difference;rk_initial_value_difference;pd78_initial_value_difference ];
    dX_lp = [RKV89_last_point_difference(1);ABM_last_point_difference(1);RK_last_point_difference(1);PD78_last_point_difference(1);RKV89_emb_last_point_difference(1)];
    dY_lp = [RKV89_last_point_difference(2);ABM_last_point_difference(2);RK_last_point_difference(2);PD78_last_point_difference(2);RKV89_emb_last_point_difference(2)];
    dZ_lp = [RKV89_last_point_difference(3);ABM_last_point_difference(3);RK_last_point_difference(3);PD78_last_point_difference(3);RKV89_emb_last_point_difference(3)];
    dVX_lp = [RKV89_last_point_difference(4);ABM_last_point_difference(4);RK_last_point_difference(4);PD78_last_point_difference(4);RKV89_emb_last_point_difference(4)];
    dVY_lp = [RKV89_last_point_difference(5);ABM_last_point_difference(5);RK_last_point_difference(5);PD78_last_point_difference(5);RKV89_emb_last_point_difference(5)];
    dVZ_lp = [RKV89_last_point_difference(6);ABM_last_point_difference(6);RK_last_point_difference(6);PD78_last_point_difference(6);RKV89_emb_last_point_difference(6)];
    dX_lp_scalar = [sqrt(dX_lp(1)^2+dY_lp(1)^2+dZ_lp(1)^2);sqrt(dX_lp(2)^2+dY_lp(2)^2+dZ_lp(2)^2);sqrt(dX_lp(3)^2+dY_lp(3)^2+dZ_lp(3)^2);sqrt(dX_lp(4)^2+dY_lp(4)^2+dZ_lp(4)^2);sqrt(dX_lp(5)^2+dY_lp(5)^2+dZ_lp(5)^2)];
    dVX_lp_scalar = [sqrt(dVX_lp(1)^2+dVY_lp(1)^2+dVZ_lp(1)^2);sqrt(dVX_lp(2)^2+dVY_lp(2)^2+dVZ_lp(2)^2);sqrt(dVX_lp(3)^2+dVY_lp(3)^2+dVZ_lp(3)^2);sqrt(dVX_lp(4)^2+dVY_lp(4)^2+dVZ_lp(4)^2);sqrt(dVX_lp(5)^2+dVY_lp(5)^2+dVZ_lp(5)^2)];
    T_last_points_diff = table(dX_lp,dY_lp,dZ_lp,dVX_lp,dVY_lp,dVZ_lp,dX_lp_scalar,dVX_lp_scalar,'RowNames',Integrators);
end

%% Checking accuracy of the integrators

if reverse_check == true
    %Reverse method
    if RKV_89 == true
        if simpleRKV89 == true
            checkrkv89 = true;
            et_vector_reversed = fliplr(et_vector);
            [orbit_rkv89_reversed, tourrkv] = RKV89_2(@force_model,et_vector_reversed,orbit_rkv89(:,length(orbit_rkv89)), length(et_vector_reversed));
            rkv89_conditions_difference = abs(fliplr(orbit_rkv89_reversed) - orbit_rkv89);
            rkv89_flp = fliplr(orbit_rkv89_reversed);
            rkv89_initial_value_difference = abs(rkv89_flp(:,1) - orbit_rkv89(:,1));
            disp('difference RKV_89');
            disp(rkv89_initial_value_difference);
        end
        if embedded_estimation == true
            checkrkv89_emb = true;

            [epochs_reversed, orbit_rkv89_emb_reversed] = rkv89emb(@force_model, [et_vector(length(et_vector)) et_vector(1)], orbit_rkv89_emb(:,length(orbit_rkv89_emb)));
            
        %rkv89emb_conditions_difference = abs(fliplr(orbit_rkv89_reversed) - orbit_rkv89);
        rkv89emb_flp = fliplr(orbit_rkv89_emb_reversed);
        rkv89emb_initial_value_difference = abs(rkv89emb_flp(:,1) - orbit_rkv89_emb(:,1));
        disp('difference RKV_89_emb');
        disp(rkv89emb_initial_value_difference);


        end
    end

    if ABM == true
        checkabm = true;

        abm_et_vector_reversed = fliplr(abm_et_vector);
        [orbit_ab8_reversed, tour] = adambashforth8(@force_model,abm_et_vector_reversed,orbit_ab8(:,length(orbit_ab8)), length(abm_et_vector_reversed));
        abm_conditions_difference = abs(fliplr(orbit_ab8_reversed) - orbit_ab8);
        abm_flp = fliplr(orbit_ab8_reversed);
        abm_initial_value_difference = abs(abm_flp(:,1) - orbit_ab8(:,1));
        disp('difference ABM');
        disp(abm_initial_value_difference);  
    end

    if RK45 == true

        checkrk = true;

        et_vector_reversed = fliplr(et_vector);%fliplr(orbit.x);
        orbit_reversed = ode45(@(t,y) force_model(t,y),et_vector_reversed,orbit.y(:,length(orbit.y)),options);  
        rk_conditions_difference = abs(fliplr(orbit_reversed.y) - orbit.y(:,1:length(orbit_reversed.y)));
        rk_flp = fliplr(orbit_reversed.y);
        rk_initial_value_difference = abs(rk_flp(:,1) - orbit.y(:,1));
        disp('difference RK45');
        disp(rk_initial_value_difference);  
    end

    if PD78 == true

    checkpd78 = true;
        
        r_options87 = odeset('RelTol',1e-13,'AbsTol',1e-13, 'MaxStep',-2700,'InitialStep',-60);
        pd78_vector_reversed = fliplr(pd78_et_vector);
        [tour1, orbit_ode87_reversed] = ode87_reversed(@(t,y) force_model(t,y),[pd78_vector_reversed(1) pd78_vector_reversed(length(pd78_vector_reversed))],orbit_ode87(:,length(orbit_ode87)), r_options87);
        orbit_ode87_reversed = orbit_ode87_reversed';
       % pd78_conditions_difference = abs(fliplr(orbit_ode87_reversed) - orbit_ode87(:,1:length(orbit_ode87_reversed)));
        pd78_flp = fliplr(orbit_ode87_reversed);
        pd78_initial_value_difference = abs(pd78_flp(:,1) - orbit_ode87(:,1));
        disp('difference PD78');
        disp(pd78_initial_value_difference);  
    end

    %% Create a table with results

    Integrators = {'RKV89';'ABM';'RK45';'PD78';'RKV89_embedded'};
    
    if RKV_89 && ~simpleRKV89
        rkv89_initial_value_difference = zeros(6,1);
        if ~embedded_estimation
            rkv89emb_initial_value_difference = zeros(6,1);
       end
    end
    if ~RKV_89 
        rkv89_initial_value_difference = zeros(6,1);
        rkv89emb_initial_value_difference = zeros(6,1);
%         if ~embedded_estimation == true
%            rkv89emb_initial_value_difference = zeros(6,1);
%         end
    end
    if ~ABM
        abm_initial_value_difference = zeros(6,1);
    end
    if ~RK45 
        rk_initial_value_difference = zeros(6,1);
    end
    if ~PD78 
        pd78_initial_value_difference = zeros(6,1);
    end
    Init_diffs = [rkv89_initial_value_difference;abm_initial_value_difference;rk_initial_value_difference;pd78_initial_value_difference;rkv89_initial_value_difference];
    %x_diffs = [rkv89_initial_value_difference;abm_initial_value_difference;rk_initial_value_difference;pd78_initial_value_difference ];
    dX = [rkv89_initial_value_difference(1);abm_initial_value_difference(1);rk_initial_value_difference(1);pd78_initial_value_difference(1);rkv89emb_initial_value_difference(1)];
    dY = [rkv89_initial_value_difference(2);abm_initial_value_difference(2);rk_initial_value_difference(2);pd78_initial_value_difference(2);rkv89emb_initial_value_difference(2)];
    dZ = [rkv89_initial_value_difference(3);abm_initial_value_difference(3);rk_initial_value_difference(3);pd78_initial_value_difference(3);rkv89emb_initial_value_difference(3)];
    dVX = [rkv89_initial_value_difference(4);abm_initial_value_difference(4);rk_initial_value_difference(4);pd78_initial_value_difference(4);rkv89emb_initial_value_difference(4)];
    dVY = [rkv89_initial_value_difference(5);abm_initial_value_difference(5);rk_initial_value_difference(5);pd78_initial_value_difference(5);rkv89emb_initial_value_difference(5)];
    dVZ = [rkv89_initial_value_difference(6);abm_initial_value_difference(6);rk_initial_value_difference(6);pd78_initial_value_difference(6);rkv89emb_initial_value_difference(6)];
    dX_scalar = [sqrt(dX(1)^2+dY(1)^2+dZ(1)^2);sqrt(dX(2)^2+dY(2)^2+dZ(2)^2);sqrt(dX(3)^2+dY(3)^2+dZ(3)^2);sqrt(dX(4)^2+dY(4)^2+dZ(4)^2);sqrt(dX(5)^2+dY(5)^2+dZ(5)^2)];
    dVX_scalar = [sqrt(dVX(1)^2+dVY(1)^2+dVZ(1)^2);sqrt(dVX(2)^2+dVY(2)^2+dVZ(2)^2);sqrt(dVX(3)^2+dVY(3)^2+dVZ(3)^2);sqrt(dVX(4)^2+dVY(4)^2+dVZ(4)^2);sqrt(dVX(5)^2+dVY(5)^2+dVZ(5)^2)];
    Table = table(dX,dY,dZ,dVX,dVY,dVZ,dX_scalar,dVX_scalar,'RowNames',Integrators);
end
%T = table(Integrators,Init_diffs);

%% The differences
%difference_rkv89emb = abs(Gmat(:,1:5859) - orbit_rkv89_emb(:,1:5859));
%difference_ab8 = abs(Gmat - orbit_ab8);
%difference_rkv89 = abs(Gmat - orbit_rkv89);


%% Total Energy checks
if check_energy == true
    if RKV_89 == true && simpleRKV89 == true
        energy_rkv89 = zeros(1, length(et_vector));
        % First calculate the initial energies
        b = [sat, earth_init, sun_init, moon_init, jupiter_init, venus_init, mars_init, saturn_init];
        [init_total, init_kinetic, init_potential] = calculate_energy(b);
        Initial_energy = init_total;
        Initial_kinetic = init_kinetic;
        Initial_potential = init_potential;

        % Calculate for each step
        for epoch = 1:length(et_vector)
            % Create a structure for the satellite
            sat_at_this_time = create_sat_structure(orbit_rkv89(:,epoch));
            % Information about planets at a given epoch
            [earth, sun, moon, jupiter, venus, mars, saturn] = create_structure( planets_name_for_struct, et_vector(epoch), observer);
            bodies = [sat_at_this_time, earth, sun, moon, jupiter, venus, mars, saturn];
            [total, kinetic, potential] = calculate_energy(bodies);
            kin1 = kinetic - Initial_kinetic;
            pot1 = potential - Initial_potential;
            tot1 = total - Initial_energy;

            energy_rkv89(1,epoch) = abs(tot1);
        end
    end
    
    if ABM == true
        energy_abm = zeros(1, length(abm_et_vector));
        % First calculate the initial energies
        b = [sat, earth_init, sun_init, moon_init, jupiter_init, venus_init, mars_init, saturn_init];
        [init_total, init_kinetic, init_potential] = calculate_energy(b);
        Initial_energy = init_total;
        Initial_kinetic = init_kinetic;
        Initial_potential = init_potential;

        % Calculate for each step
        for epoch = 1:length(abm_et_vector)
            % Create a structure for the satellite
            sat_at_this_time = create_sat_structure(orbit_ab8(:,epoch));
            % Information about planets at a given epoch
            [earth, sun, moon, jupiter, venus, mars, saturn] = create_structure( planets_name_for_struct, et_vector(epoch), observer);
            bodies = [sat_at_this_time, earth, sun, moon, jupiter, venus, mars, saturn];
            [total, kinetic, potential] = calculate_energy(bodies);
            kin1 = kinetic - Initial_kinetic;
            pot1 = potential - Initial_potential;
            tot1 = total - Initial_energy;

            energy_abm(1,epoch) = abs(tot1);
        end
    end
    
    if RK45 == true
        energy_rk = zeros(1, length(et_vector));
        % First calculate the initial energies
        b = [sat, earth_init, sun_init, moon_init, jupiter_init, venus_init, mars_init, saturn_init];
        [init_total, init_kinetic, init_potential] = calculate_energy(b);
        Initial_energy = init_total;
        Initial_kinetic = init_kinetic;
        Initial_potential = init_potential;

        % Calculate for each step
        for epoch = 1:length(orbit.y)
            % Create a structure for the satellite
            sat_at_this_time = create_sat_structure(orbit.y(:,epoch));
            % Information about planets at a given epoch
            [earth, sun, moon, jupiter, venus, mars, saturn] = create_structure( planets_name_for_struct, et_vector(epoch), observer);
            bodies = [sat_at_this_time, earth, sun, moon, jupiter, venus, mars, saturn];
            [total, kinetic, potential] = calculate_energy(bodies);
            kin1 = kinetic - Initial_kinetic;
            pot1 = potential - Initial_potential;
            tot1 = total - Initial_energy;

            energy_rk(1,epoch) = abs(tot1);
        end
    end
    
    if PD78 == true
        energy_pd78 = zeros(1, length(et_vector));
        % First calculate the initial energies
        b = [sat, earth_init, sun_init, moon_init, jupiter_init, venus_init, mars_init, saturn_init];
        [init_total, init_kinetic, init_potential] = calculate_energy(b);
        Initial_energy = init_total;
        Initial_kinetic = init_kinetic;
        Initial_potential = init_potential;

        % Calculate for each step
        for epoch = 1:length(et_vector)
            % Create a structure for the satellite
            sat_at_this_time = create_sat_structure(orbit_ode87(:,epoch));
            % Information about planets at a given epoch
            [earth, sun, moon, jupiter, venus, mars, saturn] = create_structure( planets_name_for_struct, et_vector(epoch), observer);
            bodies = [sat_at_this_time, earth, sun, moon, jupiter, venus, mars, saturn];
            [total, kinetic, potential] = calculate_energy(bodies);
            kin1 = kinetic - Initial_kinetic;
            pot1 = potential - Initial_potential;
            tot1 = total - Initial_energy;

            energy_pd78(1,epoch) = abs(tot1);
        end
    end
end
%% Plotting
figure(25)
view(3)
grid on
hold on
plot3(0,0,0,'*r');
if check_with_the_reference == true
    plot3(Gmat(1,:),Gmat(2,:),Gmat(3,:),'b');% Reference
end
%plot3(Gmat(1,1:15000),Gmat(2,1:15000),Gmat(3,1:15000),'b');
if RK45 == true
   plot3(orbit.y(1,:),orbit.y(2,:),orbit.y(3,:),'r');% RK45
  %  plot3(rk_orbitL2(1,:),rk_orbitL2(2,:),rk_orbitL2(3,:),'r');% RK45
end
if ABM == true
    plot3(orbit_ab8(1,:),orbit_ab8(2,:),orbit_ab8(3,:),'g'); % ABM8
    difference_abm = abs(Gmat(:,1:length(orbit_ab8)) - orbit_ab8);
end
if RKV_89 == true
    if simpleRKV89 == true
    plot3(orbit_rkv89(1,:),orbit_rkv89(2,:),orbit_rkv89(3,:),'c'); % RKV89
    difference_rkv89 = abs(Gmat(:,1:length(orbit_rkv89)) - orbit_rkv89);
    end
    if embedded_estimation == true
    %plot3(orbit_rkv89_emb(1,:),orbit_rkv89_emb(2,:),orbit_rkv89_emb(3,:),'m'); % RKV89 with real error estimate
    plot3(totalorbit_rkv89(1,:),totalorbit_rkv89(2,:),totalorbit_rkv89(3,:),'m');
    end
    %plot3(orbit_rkv89(1,:),orbit_rkv89(2,:),orbit_rkv89(3,:),'c');
end
if PD78 == true
    plot3(orbit_ode87(1,:),orbit_ode87(2,:),orbit_ode87(3,:),'y'); % RK87
    difference_pd78 = abs(Gmat(:,1:length(orbit_ode87)) - orbit_ode87);
end
% figure(2)
% grid on
% hold on
% plot(et_vector(1,1:5859),difference_rkv89emb(1,1:5859),et_vector(1,1:5859),difference_rkv89emb(2,1:5859),et_vector(1,1:5859),difference_rkv89emb(3,1:5859) );% Reference
if RKV_89 == true
    if simpleRKV89 == true
        figure(3)
        grid on
        hold on
        plot(et_vector,difference_rkv89(1,:),et_vector,difference_rkv89(2,:),et_vector,difference_rkv89(3,:));% Reference

    end
    if embedded_estimation == true
        figure(12)
        grid on
        hold on
        plot(epochs(1:5874),difference_rkv89_emb(1,:),epochs(1:5874),difference_rkv89_emb(2,:),epochs(1:5874),difference_rkv89_emb(3,:));
    
    end
end

if PD78 == true
    figure(4)
    grid on
    hold on
    plot(pd78_et_vector,difference_pd78(1,:),pd78_et_vector,difference_pd78(2,:),pd78_et_vector,difference_pd78(3,:));% Reference

end

if ABM == true
    figure(5)
    grid on
    hold on
    plot(abm_et_vector,difference_abm(1,:),abm_et_vector,difference_abm(2,:),abm_et_vector,difference_abm(3,:));% Reference

end

%% Energy calculation figures
if check_energy == true
    if RKV_89 == true
        figure(8)
        grid on
        hold on
        plot(et_vector,energy_rkv89);
    end

    if ABM == true
        figure(9)
        grid on
        hold on
        plot(abm_et_vector,energy_abm);
    end

    if RK45 == true
        figure(10)
        grid on
        hold on
        plot(et_vector,energy_rk);
    end
    
    if PD78 == true
        figure(11)
        grid on
        hold on
        plot(et_vector,energy_pd78);
    end
end



%% Plots info
figure(3)
title('Reference vs Integration');
legend('Reference','RK45','ABM8', 'RKV89', 'RKV89 embedded');
xlabel('x');
ylabel('y');
grid on


