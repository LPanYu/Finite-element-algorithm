function u = poisson1(node,elem,pde)
%求解一个possion方程的有限元程序

N = size(node,1);  NT = size(elem,1); 
Ndof = N;

%计算局部梯度算子
[Dphi,area] = gradbasis(node,elem);

%组装刚度矩阵A
A = sparse(Ndof,Ndof);
for i = 1:3
    for j = i:3
        % $A_{ij}|_{\tau} = \int_{\tau}K\nabla \phi_i\cdot \nabla \phi_j dxdy$ 
        Aij = (Dphi(:,1,i).*Dphi(:,1,j) + Dphi(:,2,i).*Dphi(:,2,j)).*area;
        if (j==i)
            A = A + sparse(elem(:,i),elem(:,j),Aij,Ndof,Ndof);
        else
            A = A + sparse([elem(:,i);elem(:,j)],[elem(:,j);elem(:,i)],...
                           [Aij; Aij],Ndof,Ndof);        
        end        
    end
end
clear K Aij

% 组装右端项b
b = zeros(Ndof,1);

%参见quadpts.html,command window输入doc quadpts
[lambda,weight] = quadpts(3);  
phi = lambda;
nQuad = size(lambda,1);
bt = zeros(NT,3);
for p = 1:nQuad
    pxy = lambda(p,1)*node(elem(:,1),:) ...
        + lambda(p,2)*node(elem(:,2),:) ...
        + lambda(p,3)*node(elem(:,3),:);
    fp = pde.f(pxy);
    for i = 1:3
        bt(:,i) = bt(:,i) + weight(p)*phi(p,i)*fp;
    end
end
    bt = bt.*repmat(area,1,3);
    b = accumarray(elem(:),bt(:),[Ndof 1]);
clear pxy bt

% 边界条件的处理(移到右端项,并对b进行修改)
u = zeros(Ndof,1);
fixedNode = []; %边界点 
freeNode = [];  %内部点
[fixedNode,bdEdge,isBdNode] = findboundary(elem);
freeNode = find(~isBdNode);

% AD(fixedNode,fixedNode)=I, AD(fixedNode,freeNode)=0, AD(freeNode,fixedNode)=0
if ~isempty(fixedNode)
    bdidx = zeros(Ndof,1); 
    bdidx(fixedNode) = 1;
    Tbd = spdiags(bdidx,0,Ndof,Ndof);
    T = spdiags(1-bdidx,0,Ndof,Ndof);
    AD = T*A*T + Tbd;
else
    AD = A;
end

% 修改右端项b
u(fixedNode) = 0;  %第一类边界条件,边界处的值为0
b = b - A*u;

%求解线性方程组
u(freeNode) = AD(freeNode,freeNode)\b(freeNode);
end
    
