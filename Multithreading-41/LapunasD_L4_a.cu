#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <cuda.h>

#include <omp.h>
#include <string>
#include <fstream>
#include <vector>
#include <iomanip>
#include <iostream>
#include <sstream>

using namespace std;

struct GpuStruct
{
        char *pav;
        int kiekis;
        double kaina;
		int strlen;
		GpuStruct();
};

class Struct
{
        string pav;
        int kiekis;
        double kaina;
        GpuStruct gpuStruct;
public:
        Struct(string input = " 0 0");
		Struct();
        ~Struct(){cudaFree(gpuStruct.pav);}
        GpuStruct GetDev(){return gpuStruct;}
        string Print();
};

Struct::Struct(string input)
{
        int start, end;
        start = 0;
        end = input.find(' ');
        pav = input.substr(0, end).c_str();
        start = end + 1;
        end = input.find(' ', start);
        kiekis = stoi(input.substr(start, end - start));
        start = end + 1;
        kaina = stod(input.substr(start));
        gpuStruct.kaina = kaina;
        gpuStruct.kiekis = kiekis;
		gpuStruct.strlen = pav.length();
        cudaMalloc(&gpuStruct.pav, pav.size() + 1);
        cudaMemcpy(gpuStruct.pav, pav.c_str(), pav.size() + 1, cudaMemcpyHostToDevice);
}

string Struct::Print()
{
        stringstream ss;
        ss << setw(15) << pav << setw(7) << kiekis << setw(20) << kaina;
        return ss.str();
}

vector<vector<Struct>> ReadStuff(string file);
vector<string> ReadLines(string file);

string Titles();
string Print(int nr, Struct &s);
void syncOut(vector<vector<Struct>>&);

void __global__ Add(GpuStruct *data, int *starts, int arrCount, GpuStruct *res);

int main()
{
        auto input = ReadStuff("LapunasD.txt");
        int count = 0;
        //suskaiciuojama kiek is viso yra duomenu
        for(auto &vec : input)
                count += vec.size();
		int width = 0;
		for(auto &vec : input)
				width = vec.size() > width ? vec.size() : width;

        cout << "\nsinchroninis isvedimas\n\n";
        syncOut(input);
        cout << "\nasinchroninis isvedimas\n\n";
        cout << setw(10) << "Procesas" << setw(3) << "Nr" << Titles() << "\n\n";
        
        //procesu duomenu pradzios indeksai
        vector<int> starts;
        //lokalios GPU strukturu kopijos
        vector<GpuStruct> localStructs;
        
        int put = 0;
        for(auto &vec : input)
        {
                //proceso pradzia
                starts.push_back(put);
                for(auto &s : vec)
                {
                        localStructs.push_back(s.GetDev());
                        put++;
                }
        }
        starts.push_back(put);
        int *startsdev;
        //pradziu masyvas GPU
        cudaMalloc(&startsdev, sizeof(int) * starts.size());
        cudaMemcpy(startsdev, &starts[0], sizeof(int) * starts.size(), cudaMemcpyHostToDevice);
        GpuStruct *arr;
        //strukturu masyvas GPU
        cudaMalloc(&arr, sizeof(GpuStruct) * count);
        cudaMemcpy(arr, &localStructs[0], sizeof(GpuStruct) * count, cudaMemcpyHostToDevice);
        //GPU funkcija
        GpuStruct* gpuRes;

		cudaMalloc(&gpuRes, sizeof(GpuStruct) * width);

        Add<<<1, width>>>(arr, startsdev, input.size(), gpuRes);
        //palaukiam kol gpu baigs spausdint, "pause" uzrakina konsole
        cudaDeviceSynchronize();
        system("pause");
        //atlaisvinami pagrindiniai masyvai, teksto eilutes atlaisvinamos sunaikintant pagrindines strukturas - input
        cudaFree(arr);
        cudaFree(startsdev);
        return 0;

}

vector<vector<Struct>> ReadStuff(string file)
{
        auto lines = ReadLines(file);
        vector<vector<Struct>> ret;
        vector<Struct> tmp;
        for(size_t i = 0; i < lines.size(); i++)
        {
                if(lines[i] == "")
                {
                        ret.push_back(move(tmp));
                }
                else
                {
                        tmp.emplace_back(lines[i]);
                }
        }
        return ret;
}

vector<string> ReadLines(string file)
{
        vector<string> ret;
        ifstream duom(file);
        while(!duom.eof())
        {
                string line;
                getline(duom, line);
                ret.push_back(line);
        }
        return ret;
}

string Titles()
{
        stringstream ss;
        ss << setw(15) << "Pavadiniams" << setw(7) << "Kiekis" << setw(20) << "Kaina";
        return ss.str();
}

void syncOut(vector<vector<Struct>> &data)
{
        cout << setw(3) << "Nr" << Titles() << endl << endl;
        for(size_t i = 0; i < data.size(); i++)
        {
                auto &vec = data[i];
                cout << "Masyvas" << i << endl;
                for(size_t j = 0; j < vec.size(); j++)
                {
                        cout << Print(j, vec[j]) << endl;
                }
        }
}

string Print(int nr, Struct &s)
{
        stringstream ss;
        ss << setw(3) << nr << s.Print();
        return ss.str();
}

void __global__ Add(GpuStruct *data, int *starts, int arrCount, GpuStruct *res)
{
	int id = threadIdx.x;
	int length = 0;
	for(int i = 0; i < arrCount; i++)
	{
		if(starts[i] + id < starts[i+1])
			length += data[starts[i]].strlen + id;
	}
	res[id].strlen = length;
	cudaMallock(&res[id].pav, length + 1);
	res[id].pav[length] = 0;
	int ind = 0;
	for(int i = 0; i < arrCount; i++)
	{
		
	}
}