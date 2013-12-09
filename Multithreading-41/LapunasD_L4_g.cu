//Darius Lapunas, IFF-1, 15 kompiuteris
/*
	Pakeista:
	77
	122-126
	140-146
	152-155
	243-247
*/

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
        char pav[50];
        int kiekis;
        double kaina;
};

class Struct
{
        string pav;
        int kiekis;
        double kaina;
        GpuStruct gpuStruct;
public:
        Struct(string input = " 0 0");
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
		memcpy(gpuStruct.pav, pav.c_str(), pav.length() + 1);
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
void __global__ Gynimas(GpuStruct *data, double *res);

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
		cudaMemcpy(startsdev, starts.data(), sizeof(int) * starts.size(), cudaMemcpyHostToDevice);
        GpuStruct *arr;
        //strukturu masyvas GPU
        cudaMalloc(&arr, sizeof(GpuStruct) * count);
		cudaMemcpy(arr, localStructs.data(), sizeof(GpuStruct) * count, cudaMemcpyHostToDevice);

        GpuStruct* gpuRes;
		cudaMalloc(&gpuRes, sizeof(GpuStruct) * width);

		double *gpuGynimasRes;
		int gynimoDydis = input[0].size();
		cudaMalloc(&gpuGynimasRes, sizeof(double) * gynimoDydis);
		
		Gynimas<<<1, gynimoDydis>>>(arr, gpuGynimasRes);
        Add<<<1, width>>>(arr, startsdev, input.size(), gpuRes);
        //palaukiam kol gpu baigs spausdint, "pause" uzrakina konsole
        cudaDeviceSynchronize();

		GpuStruct *res = new GpuStruct[width];
		cudaMemcpy(res, gpuRes, sizeof(GpuStruct) * width, cudaMemcpyDeviceToHost);
		
        cout << "\n\n" << setw(3) << "Nr" << setw(30) << "Pavadiniams" << setw(7) << "Kiekis" << setw(10) << "Kaina" << "\n\n";
		for(int i = 0; i < width; i++)
		{
			cout << setw(3) << i << setw(30) << res[i].pav << setw(7) << res[i].kiekis << setw(10) << res[i].kaina << endl;
		}

		cout << "\nGynimas:\n";
		double *localGynimasRes = new double[gynimoDydis];
		cudaMemcpy(localGynimasRes, gpuGynimasRes, sizeof(double) * gynimoDydis, cudaMemcpyDeviceToHost);
		for(int i = 0; i < gynimoDydis; i++)
		{
			cout << i << "   " << localGynimasRes[i] << endl;
		}

        system("pause");
        //atlaisvinami pagrindiniai masyvai, teksto eilutes atlaisvinamos sunaikintant pagrindines strukturas - input
        cudaFree(arr);
        cudaFree(startsdev);
		cudaFree(gpuRes);
		cudaFree(gpuGynimasRes);
		delete res;
		delete localGynimasRes;
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

	GpuStruct *myRes = res + id;
	myRes->kaina = 0.0;
	myRes->kiekis = 0;
	int ind = 0;
	for(int i = 0; i < arrCount; i++)
	{
		if(starts[i] + id < starts[i+1])
		{
			GpuStruct *src = data + starts[i] + id;
			myRes->kaina += src->kaina;
			myRes->kiekis += src->kiekis;
			for(int j = 0; src->pav[j] != 0; j++, ind++)
			{
				myRes->pav[ind] = src->pav[j];
			}
		}
	}
	myRes->pav[ind] = 0;
}

void __global__ Gynimas(GpuStruct *data, double *res)
{
	int id = threadIdx.x;
	res[id] = data[id].kiekis + data[id].kaina;
}