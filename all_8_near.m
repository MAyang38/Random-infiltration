% 模拟区大小

area_width   = 40;
area_high    = 48;
grid_width   = 0.4;
gird_high    = 0.4;

% 网格长宽个数
cell_x = area_width/grid_width;
cell_y = area_high/gird_high;
% 饱和度矩阵
S =  zeros(cell_y, cell_x);
% sigma 界面张力
sigma        = 0.03;
% theta 接触角
theta        = 2.18;
% 求网格单元的孔隙特征尺寸（representative pore radius）所需a、b
a            = 1923;
b            = 1.94;

% 计算Ip所需参数
% ?ρ为两种流体的密度差
deta_p = 0.465;
% g为重力加速度
g = 9.8;

% pn 密度
pn = 1465;

% Dp 溶液高度
Dp = 1;
% Phi 孔隙度
Phi = 0.3;

% 渗透系数lnK∈[0.86, 3.68] 均值2.5 方差0.2
lnK = normrnd(2.5, sqrt(2), [cell_y cell_x]);

% 渗透系数场K
K = exp(lnK);

% 求网格单元的孔隙特征尺寸r
dm = (K/(0.0489 * a)).^(1/b);

rp = 0.212*dm;
rt = 0.077*dm;
% r的分子分母
r_zi = rp.*rt;
r_mu = rp - rt;
r    = r_zi./r_mu;

% 计算初始压力
Pd = 2*sigma*cos(theta)*(1./r);
Pc = Pd;

lamdab = 2;
% Ips :当前所有已侵入的点
Ips = [];

% 是否泄漏到最底部  0为否
is_bottom = 0;

low_x = 0;
low_y = 0;
% 初始点
entry_point = [];
entry_max = 0;
% 最底端侵入点
cur_point = [];

% qinru_x
qinru_x = [1 1 1 0 -1 -1 -1 0];
qinru_y = [0 1 -1 1 0 1 -1 -1];


is_in_matrix = zeros(cell_y, cell_x);

% 计算初始泄露处三个位置[49, 1]、[50,1]、[51, 1]的Ip
for i = 49:51
    Ip = Ip_compute(pn, g, Dp, deta_p, 1, Pd(1,i));
    fprintf('%d   ', Ip);
    if (Ip > entry_max)
        entry_point = [1 i];
        entry_max = Ip;
    end
end
cur_point = entry_point;
% 初始点饱和度加0.1
index_x = cur_point(1);
index_y = cur_point(2);
S(index_x, index_y) = 0.1;
% 更新的Dp
Se_sum = sum(sum(S));
Dp = 1 - (Se_sum * Phi * grid_width * gird_high )/1.2;

%  更新Pd

Pd(index_x, index_y) = Pc(index_x, index_y)/(S(index_x, index_y)^(-1/lamdab));
% 前两列为点的位置， 最后一列为此点的ip值
Ips = [cur_point entry_max];
d = 0;


% 当溶液高度为0 或者 渗入到模拟区域底部结束循环
while(Dp > 0 && is_bottom ~=1)
% while(d)
    is_in_matrix = zeros(cell_y, cell_x);
    d = d +1;
    % 存放此轮所需计算点的IP
    IP_temp = [];
%     fprintf(Ips);
    % 更新已有的点的Ip， 第三列为Ip的值，前两列为点的行与列
    [m, n] = size(Ips);
    fprintf("%d  %d    \n",m, n );


    for i = 1:m
        Ips(i,3) = Ip_compute(pn, g, Dp, deta_p, Ips(i, 1), Pd(Ips(i, 1), Ips(i,2)));
      %  Ips(i,4) = S(Ips(i, 1),Ips(i, 2));
       % is_in_matrix(Ips(i, 1),Ips(i, 2)) = 1;
    end
    %fprintf(Ips);

%     % 选择不饱和的点
%     IP_temp = Ips (Ips (:,4)<=0.7,:);
%     IP_temp = IP_temp(:,1:3);
%     % 找到所需要计算的IP点
%     Ips = Ips(:,1:3);
    
    for index = 1:m
        cur_x = Ips(index, 1);
        cur_y = Ips(index, 2);
        if(S(cur_x,cur_y) < 0.8 && is_in_matrix(cur_x, cur_y) == 0)
            ip = Ip_compute(pn, g, Dp, deta_p, cur_x, Pd(cur_x,cur_y));
            IP_temp = [IP_temp ;cur_x cur_y ip];
            %此点被选择
            is_in_matrix(cur_x, cur_y) = 1;
        end
        for i = 1:4
            % 判断相邻单元是否越界 如果在边界内，则执行
            x = cur_x + qinru_x(i);
            y = cur_y + qinru_y(i);
            if(x <= cell_y && x >= 1 && y <= cell_x && y >= 1)
                if(S(x,y) < 0.8 && is_in_matrix(x, y) == 0)


                    ip = Ip_compute(pn, g, Dp, deta_p, x, Pd(x,y));
                    IP_temp = [IP_temp ;x y ip];
                    %此点被选择
                    is_in_matrix(x, y) = 1;
                end
            end
        end
    
    end
 
%     % 将相邻接触单元放入点阵中
%     for i = 1:4
%         % 判断相邻单元是否越界 如果在边界内，则执行
%         x = cur_x + qinru_x(i);
%         y = cur_y + qinru_y(i);
%         if(x <= cell_y && x >= 1 && y <= cell_x && y >= 1)
%             if(S(x,y) == 0)
%                 ip = Ip_compute(pn, g, Dp, deta_p, x, Pd(x,y));
%                 IP_temp = [IP_temp ;x y ip];
%             end
%         end
%     end
    % 比较所有的Ip 并按Ip降序排列
    IP_temp = sortrows(IP_temp,-3); % sortrows(Ips,-3)


    % 随机选择侵入单元：生成[0,1]均匀分布的随机数w，的结果计算∑?I_p 
    w = unifrnd(0, 1, 1, 1);
    Ip_sum = sum(IP_temp(:,3));
    R = w * Ip_sum;
    % 选择侵入点
    [m, n] = size(IP_temp);
    
    % index 所选择的点行数
    index = 1;
    % 求得到负值的点
    while(R > 0)
%         if(S(IP_temp))
        R = R - IP_temp(index, 3);
%         % 判断是否饱和
%         if(R < 0 && S(IP_temp(i,1), IP_temp(i, 2)) == 0.8)
%             R = R + IP_temp(i, 3);
%         elseif(R > 0 && S(IP_temp(i,1), IP_temp(i, 2)) ~= 0.8)
%             choose_point = [IP_temp(i,1), IP_temp(i, 2)];
%         end
        if (R > 0)
            index = index + 1;
        end
    end
    if (index > 1)
        index = index - 1;
    end
    % 选择index侵入
    entry_point = IP_temp(index:index,1:2);
    if(S(IP_temp(index,1), IP_temp(index, 2)) == 0)
        Ips = [Ips;IP_temp(index:index,:)];
    end

    fprintf("入侵点为%d %d   饱和度为%d\n",IP_temp(index,1), IP_temp(index, 2),S(IP_temp(index,1), IP_temp(index, 2)) );
    % 6. 更新饱和度矩阵
    S(IP_temp(index,1), IP_temp(index, 2)) =  S(IP_temp(index,1), IP_temp(index, 2)) + 0.1;
    

    % 7. 更新Dp
    Se_sum = sum(sum(S));
    Dp = 1 - (Se_sum * Phi * grid_width * gird_high)/1.2;
%     fprintf("%d", Dp);
    % 8. 更新Pd
    index_x = entry_point(1);
    index_y = entry_point(2);
    Pd(index_x, index_y) = Pc(index_x, index_y)/(S(index_x, index_y)^(-1/lamdab));
    
    if(index_x > low_x)
        low_x = index_x;
        low_y = index_y;
    end
%     cur_point = [low_x, low_y];
    cur_point = entry_point;
    % 判断是否到达最底端
    if(low_x == 120)
        is_bottom = 1;
    end
end





% 创建 figure
figure1 = figure;
colormap(cool);

% 创建 axes
axes1 = axes('Parent',figure1);
hold(axes1,'on');

% 创建 image
image(S,'Parent',axes1,'CDataMapping','scaled');

% 创建 ylabel
ylabel({'Z/m'});

% 创建 xlabel
xlabel({'X/m'});

% 取消以下行的注释以保留坐标区的 X 范围
% xlim(axes1,[36.7350830364225 68.5981648074581]);
% 取消以下行的注释以保留坐标区的 Y 范围
% ylim(axes1,[0.500000000000002 38.7356981252428]);
box(axes1,'on');
axis(axes1,'ij');
hold(axes1,'off');
% 设置其余坐标区属性
set(axes1,'CLim',[0 0.8],'Colormap',...
    [1 1 1;0.967741935483871 0.967741935483871 1;0.935483870967742 0.935483870967742 1;0.903225806451613 0.903225806451613 1;0.870967741935484 0.870967741935484 1;0.838709677419355 0.838709677419355 1;0.806451612903226 0.806451612903226 1;0.774193548387097 0.774193548387097 1;0.741935483870968 0.741935483870968 1;0.709677419354839 0.709677419354839 1;0.67741935483871 0.67741935483871 1;0.645161290322581 0.645161290322581 1;0.612903225806452 0.612903225806452 1;0.580645161290323 0.580645161290323 1;0.548387096774194 0.548387096774194 1;0.516129032258065 0.516129032258065 1;0.483870967741935 0.483870967741935 1;0.451612903225806 0.451612903225806 1;0.419354838709677 0.419354838709677 1;0.387096774193548 0.387096774193548 1;0.354838709677419 0.354838709677419 1;0.32258064516129 0.32258064516129 1;0.290322580645161 0.290322580645161 1;0.258064516129032 0.258064516129032 1;0.225806451612903 0.225806451612903 1;0.193548387096774 0.193548387096774 1;0.161290322580645 0.161290322580645 1;0.129032258064516 0.129032258064516 1;0.0967741935483871 0.0967741935483871 1;0.0645161290322581 0.0645161290322581 1;0.032258064516129 0.032258064516129 1;0 0 1;0 0.015625 1;0 0.03125 1;0 0.046875 1;0 0.0625 1;0 0.078125 1;0 0.09375 1;0 0.109375 1;0 0.125 1;0 0.140625 1;0 0.15625 1;0 0.171875 1;0 0.1875 1;0 0.203125 1;0 0.21875 1;0 0.234375 1;0 0.25 1;0 0.265625 1;0 0.28125 1;0 0.296875 1;0 0.3125 1;0 0.328125 1;0 0.34375 1;0 0.359375 1;0 0.375 1;0 0.390625 1;0 0.40625 1;0 0.421875 1;0 0.4375 1;0 0.453125 1;0 0.46875 1;0 0.484375 1;0 0.5 1;0 0.515625 1;0 0.53125 1;0 0.546875 1;0 0.5625 1;0 0.578125 1;0 0.59375 1;0 0.609375 1;0 0.625 1;0 0.640625 1;0 0.65625 1;0 0.671875 1;0 0.6875 1;0 0.703125 1;0 0.71875 1;0 0.734375 1;0 0.75 1;0 0.765625 1;0 0.78125 1;0 0.796875 1;0 0.8125 1;0 0.828125 1;0 0.84375 1;0 0.859375 1;0 0.875 1;0 0.890625 1;0 0.90625 1;0 0.921875 1;0 0.9375 1;0 0.953125 1;0 0.96875 1;0 0.984375 1;0 1 1;0.015625 1 0.984375;0.03125 1 0.96875;0.046875 1 0.953125;0.0625 1 0.9375;0.078125 1 0.921875;0.09375 1 0.90625;0.109375 1 0.890625;0.125 1 0.875;0.140625 1 0.859375;0.15625 1 0.84375;0.171875 1 0.828125;0.1875 1 0.8125;0.203125 1 0.796875;0.21875 1 0.78125;0.234375 1 0.765625;0.25 1 0.75;0.265625 1 0.734375;0.28125 1 0.71875;0.296875 1 0.703125;0.3125 1 0.6875;0.328125 1 0.671875;0.34375 1 0.65625;0.359375 1 0.640625;0.375 1 0.625;0.390625 1 0.609375;0.40625 1 0.59375;0.421875 1 0.578125;0.4375 1 0.5625;0.453125 1 0.546875;0.46875 1 0.53125;0.484375 1 0.515625;0.5 1 0.5;0.515625 1 0.484375;0.53125 1 0.46875;0.546875 1 0.453125;0.5625 1 0.4375;0.578125 1 0.421875;0.59375 1 0.40625;0.609375 1 0.390625;0.625 1 0.375;0.640625 1 0.359375;0.65625 1 0.34375;0.671875 1 0.328125;0.6875 1 0.3125;0.703125 1 0.296875;0.71875 1 0.28125;0.734375 1 0.265625;0.75 1 0.25;0.765625 1 0.234375;0.78125 1 0.21875;0.796875 1 0.203125;0.8125 1 0.1875;0.828125 1 0.171875;0.84375 1 0.15625;0.859375 1 0.140625;0.875 1 0.125;0.890625 1 0.109375;0.90625 1 0.09375;0.921875 1 0.078125;0.9375 1 0.0625;0.953125 1 0.046875;0.96875 1 0.03125;0.984375 1 0.015625;1 1 0;1 0.984375 0;1 0.96875 0;1 0.953125 0;1 0.9375 0;1 0.921875 0;1 0.90625 0;1 0.890625 0;1 0.875 0;1 0.859375 0;1 0.84375 0;1 0.828125 0;1 0.8125 0;1 0.796875 0;1 0.78125 0;1 0.765625 0;1 0.75 0;1 0.734375 0;1 0.71875 0;1 0.703125 0;1 0.6875 0;1 0.671875 0;1 0.65625 0;1 0.640625 0;1 0.625 0;1 0.609375 0;1 0.59375 0;1 0.578125 0;1 0.5625 0;1 0.546875 0;1 0.53125 0;1 0.515625 0;1 0.5 0;1 0.484375 0;1 0.46875 0;1 0.453125 0;1 0.4375 0;1 0.421875 0;1 0.40625 0;1 0.390625 0;1 0.375 0;1 0.359375 0;1 0.34375 0;1 0.328125 0;1 0.3125 0;1 0.296875 0;1 0.28125 0;1 0.265625 0;1 0.25 0;1 0.234375 0;1 0.21875 0;1 0.203125 0;1 0.1875 0;1 0.171875 0;1 0.15625 0;1 0.140625 0;1 0.125 0;1 0.109375 0;1 0.09375 0;1 0.078125 0;1 0.0625 0;1 0.046875 0;1 0.03125 0;1 0.015625 0;1 0 0;0.984375 0 0;0.96875 0 0;0.953125 0 0;0.9375 0 0;0.921875 0 0;0.90625 0 0;0.890625 0 0;0.875 0 0;0.859375 0 0;0.84375 0 0;0.828125 0 0;0.8125 0 0;0.796875 0 0;0.78125 0 0;0.765625 0 0;0.75 0 0;0.734375 0 0;0.71875 0 0;0.703125 0 0;0.6875 0 0;0.671875 0 0;0.65625 0 0;0.640625 0 0;0.625 0 0;0.609375 0 0;0.59375 0 0;0.578125 0 0;0.5625 0 0;0.546875 0 0;0.53125 0 0;0.515625 0 0;0.5 0 0],...
    'Layer','top');
% 创建 colorbar
colorbar(axes1);

% % 创建 textbox
% annotation(figure1,'textbox',...
%     [0.35 0.145308439842551 0.225714290669986 0.0956439411098307],...
%     'Color',[1 0 0],...
%     'String',{'隔水边界'},...
%     'FontSize',18);
% 
% % 创建 textbox
% annotation(figure1,'textbox',...
%     [0.354999999999999 0.92 0.176428571428572 0.085714285714288],...
%     'Color',[1 0 0],...
%     'String',{'隔水边界'},...
%     'FontSize',18,...
%     'FitBoxToText','off');







% 计算ip
function ip = Ip_compute(pn, g, Dp, deta_p, zi, Pd)
% a function that calculates ip of cell.
  
    zi = (zi - 0.5) * 0.4 ;
    ip = pn * g * Dp + deta_p * g * zi - Pd;
end

