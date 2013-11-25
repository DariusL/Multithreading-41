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

void __global__ Add(GpuStruct **data, GpuStruct *ret);

int main()
{
        auto input = ReadStuff("LapunasD.txt");
        int count = 0;
		for(auto &vec : input)
			count = vec.size() > count ? vec.size() : count;
        cout << "\nsinchroninis isvedimas\n\n";
        syncOut(input);
        cout << "\nasinchroninis isvedimas\n\n";
        cout << setw(10) << "Procesas" << setw(3) << "Nr" << Titles() << "\n\n";
        
		vector<GpuStruct*> gpuStructs;

		vector<Struct> localRes;
		GpuStruct* gpuRes;

		GpuStruct** data;

		cudaMalloc(&gpuRes, sizeof(GpuStruct) * count);
		for(int i = 0; i < count; i++)
		{
			localRes.emplace_back();
			cudaMemcpy(gpuRes + i * sizeof(GpuStruct), &localRes[i], sizeof(GpuStruct), cudaMemcpyHostToDevice);
		}

		for(int i = 0; i < input.size(); i++)
		{
			GpuStruct *tmp;
			auto &vec = input[i];
			cudaMalloc(&tmp, sizeof(GpuStruct) * vec.size());

			for(int j = 0; j < vec.size(); j++)
			{
				cudaMemcpy(&tmp + j * sizeof(GpuStruct), &vec[i].GetDev(), sizeof(GpuStruct), cudaMemcpyHostToDevice);
			}
			gpuStructs.push_back(tmp);
		}

		cudaMalloc(&data, sizeof(GpuStruct*) * input.size());
		for(int i = 0; i < input.size(); i++)
		{
			cudaMemcpy(data + sizeof(GpuStruct*) * i, gpuStructs[i], sizeof(GpuStruct*), cudaMemcpyHostToDevice);
		}

		Add<<<1, input.size()>>>(data, res);

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

void __global__ Add(GpuStruct **data, GpuStruct *ret)
{
}