//Darius Lapunas, IFF-1, 15 kompiuteris
/*
	Pakeista:
	77
	122-126
	140-146
	152-155
	243-247
*/

#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <thrust/sort.h>
#include <thrust/execution_policy.h>

#include <stdio.h>
#include <cuda.h>

#include <string>
#include <fstream>
#include <vector>
#include <iomanip>
#include <iostream>
#include <sstream>

using namespace std;

__device__ void strcat_dev(char *dst, const char *src)
{
	int i = 0;
	for(; dst[i] != 0; i++);
	for(int j = 0; src[j] != 0; j++, i++)
		dst[i] = src[j];
	dst[i] = 0;
}

struct Struct
{
    char pav[50];
    int kiekis;
    double kaina;
public:
	__host__ Struct(string pav, int kiekis, double kaina);
	__device__ Struct();
    string Print();
};

__host__ Struct::Struct(string pav, int kiekis, double kaina)
	:kiekis(kiekis), kaina(kaina)
{
	this->pav[0] = 0;
	strcat(this->pav, pav.c_str());
}

__device__ Struct::Struct()
	:kiekis(0), kaina(0.0)
{
	pav[0] = 0;
}

string Struct::Print()
{
        stringstream ss;
        ss << setw(15) << pav << setw(7) << kiekis << setw(20) << kaina;
        return ss.str();
}

__device__ Struct operator+(const Struct &left, const Struct &right)
{
	Struct ret;
	ret.kiekis = left.kiekis + right.kiekis;
	ret.kaina = left.kaina + right.kaina;
	strcat_dev(ret.pav, left.pav);
	strcat_dev(ret.pav, right.pav);
	return ret;
}

vector<vector<Struct>> ReadStuff(string file);
vector<string> ReadLines(string file);

string Titles();
string Print(int nr, Struct &s);
void syncOut(vector<vector<Struct>>&);


int main()
{
    auto data = ReadStuff("LapunasD.txt");
	syncOut(data);
	vector<Struct> flatData;

	vector<int> keys;

	int width = 0;
	for(int i = 0; i < data.size(); i++)
	{
		width = data[i].size() > width ? data[i].size() : width;
		for(int j = 0; j < data[i].size(); j++)
		{
			keys.push_back(j);
			flatData.push_back(data[i][j]);
		}
	}
	
    thrust::equal_to<int> binary_pred;
    thrust::plus<Struct> binary_op;
	thrust::sort_by_key(keys.data(), keys.data() + keys.size(), flatData.data());

	thrust::host_vector<int> host_keys = keys;
	thrust::device_vector<int> device_keys = host_keys;

	thrust::host_vector<Struct> host_values = flatData;
	thrust::device_vector<Struct> device_values = host_values;

	thrust::device_vector<Struct> output_values;
	output_values.reserve(flatData.size());
	thrust::device_vector<int> output_keys;
	output_keys.reserve(flatData.size());

	thrust::reduce_by_key(device_keys.begin(), device_keys.end(), device_values.begin(), output_keys.begin(), output_values.begin(), binary_pred, binary_op);

	thrust::host_vector<int> result_keys = output_keys;
	
	cout << "\n\n" << setw(3) << "Nr" << setw(30) << "Pavadiniams" << setw(7) << "Kiekis" << setw(10) << "Kaina" << "\n\n";
	for(int i = 0; i < width; i++)
	{
		Struct res = output_values[i];
		cout << setw(3) << i << setw(30) << res.pav << setw(7) << res.kiekis << setw(10) << res.kaina << endl;
	}
	system("pause");
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
			int start, end;
			start = 0;
			end = lines[i].find(' ');
			string pav = lines[i].substr(0, end);
			start = end + 1;
			end = lines[i].find(' ', start);
			int kiekis = stoi(lines[i].substr(start, end - start));
			start = end + 1;
			double kaina = stod(lines[i].substr(start));
			tmp.emplace_back(pav.c_str(), kiekis, kaina);
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