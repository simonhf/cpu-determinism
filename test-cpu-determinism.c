#define _GNU_SOURCE /* needed for sched_getcpu() */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <locale.h>
#include <sys/time.h>
#include <assert.h>
#include <sched.h>
#include <time.h>

uint64_t iterations = 3;
uint64_t iteration = 1;
uint64_t invokes = 2000000;

inline __attribute__((always_inline)) double get_time_in_s(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL); // to compact assembly, assume this will never assert: assert(gettimeofday(&tv, NULL) >= 0);
    return (double)tv.tv_sec + 1.e-6 * (double)tv.tv_usec;
}

#ifdef USE_CLOCKGETTIME

char * use_what = "clogt"; // (clo)ck_(g)et(t)ime

struct timespec ts_start;

// see https://gist.github.com/diabloneo/9619917?permalink_comment_id=3391815
void timespecsub(struct timespec *stop, struct timespec *start, struct timespec *result) {
    if ((stop->tv_nsec - start->tv_nsec) < 0) {
        result->tv_sec = stop->tv_sec - start->tv_sec - 1;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec + 1000000000;
    }
    else {
        result->tv_sec = stop->tv_sec - start->tv_sec;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec;
    }

    return;
}

inline __attribute__((always_inline)) uint64_t get_time_in_hires_units(void) {
    struct timespec ts_now;
    struct timespec ts_diff;
    clock_gettime(CLOCK_MONOTONIC, &ts_now); // to compact assembly, assume this will never assert: assert(clock_gettime(CLOCK_MONOTONIC, &ts) >= 0);
    timespecsub(&ts_now, &ts_start, &ts_diff);
    uint64_t ns = (ts_diff.tv_sec * 1000000000) + (ts_diff.tv_nsec);
    return ns;
}

inline __attribute__((always_inline)) uint64_t diff_hires_units_as_ns(uint64_t t0, uint64_t t1) {
    return t1 - t0;
}

void ini_time(void) {
    double t0_s = get_time_in_s();
    int x = 0;
    for(uint64_t i = 0; i < invokes; i ++) {
        x += clock_gettime(CLOCK_MONOTONIC, &ts_start);
    }
    double t1_s = get_time_in_s();
    double diff_s = t1_s - t0_s;
    uint64_t ns_per_invoke = diff_s * 1000000000 / invokes;
    printf("%.6f %s // %lu=iteration using clock_gettime(CLOCK_MONOTONIC) for clock at %lu avg ns of %'lu invokes\n", get_time_in_s(), use_what, iteration, ns_per_invoke, invokes);
}

#endif

#ifdef USE_GETTIMEOFDAY

char * use_what = "gtofd"; // (g)et(ti)me(of)(d)ay

struct timeval tv_start;

inline __attribute__((always_inline)) uint64_t get_time_in_hires_units(void) {
    struct timeval tv_now;
    struct timeval tv_diff;
    gettimeofday(&tv_now, NULL); // to compact assembly, assume this will never assert: assert(gettimeofday(&tv, NULL) >= 0);
    timersub(&tv_now, &tv_start, &tv_diff);
    uint64_t ns = (tv_diff.tv_sec * 1000000000) + (tv_diff.tv_usec * 1000);
    return ns;
}

inline __attribute__((always_inline)) uint64_t diff_hires_units_as_ns(uint64_t t0, uint64_t t1) {
    return t1 - t0;
}

void ini_time(void) {
    double t0_s = get_time_in_s();
    int x = 0;
    for(uint64_t i = 0; i < invokes; i ++) {
        x += gettimeofday(&tv_start, NULL); // to compact assembly, assume this will never assert: assert(gettimeofday(&tv, NULL) >= 0);
    }
    double t1_s = get_time_in_s();
    double diff_s = t1_s - t0_s;
    uint64_t ns_per_invoke = diff_s * 1000000000 / invokes;
    printf("%.6f %s // %lu=iteration using gettimeofday() for clock at %lu avg ns of %'lu invokes\n", get_time_in_s(), use_what, iteration, ns_per_invoke, invokes);
}

#endif

#ifdef USE_RDTSC

#include <x86intrin.h>

char * use_what = "rdtsc"; // (rdtsc)

uint64_t tsc_per_second;

inline __attribute__((always_inline)) uint64_t get_time_in_hires_units(void) {
    return __rdtsc();
}

inline __attribute__((always_inline)) uint64_t diff_hires_units_as_ns(uint64_t t0, uint64_t t1) {
    return (t1 - t0) * 1000000000 / tsc_per_second;
}

void ini_time(void) {
    double t0_s = get_time_in_s();
    uint64_t t0_tsc = get_time_in_hires_units();
    usleep(10000 /* 10,000 us or 10 ms */);
    uint64_t t1_tsc = get_time_in_hires_units();
    double t1_s = get_time_in_s();
    double diff_s = t1_s - t0_s;
    uint64_t diff_tsc = t1_tsc - t0_tsc;
    tsc_per_second = diff_tsc / diff_s;
    uint64_t ns_per_invoke;
    {
        double t0_s = get_time_in_s();
        uint64_t x = 0;
        for(uint64_t i = 0; i < invokes; i ++) {
            x += get_time_in_hires_units();
        }
        double t1_s = get_time_in_s();
        double diff_s = t1_s - t0_s;
        ns_per_invoke = diff_s * 1000000000 / invokes;
    }
    printf("%.6f %s // %lu=iteration using __rdtsc() for clock at %lu avg ns of %'lu invokes; %f=diff_s %'lu=diff_tsc %'lu=tsc_per_second \n", get_time_in_s(), use_what, iteration, ns_per_invoke, invokes, diff_s, diff_tsc, tsc_per_second);
}

#endif

#ifdef USE_WITHOUTCLOCK

char * use_what = "woclo"; // (w)ith(o)ut (clo)ck

inline __attribute__((always_inline)) uint64_t get_time_in_hires_units(void) {
    return 0;
}

inline __attribute__((always_inline)) uint64_t diff_hires_units_as_ns(uint64_t t0, uint64_t t1) {
    return 0;
}

void ini_time(void) {
    printf("%.6f %s // %lu=iteration without clock timing\n", get_time_in_s(), use_what, iteration);
}

#endif

int comp (const void * elem1, const void * elem2) {
    int f = *((uint64_t*)elem1);
    int s = *((uint64_t*)elem2);
    if (f > s) return  1;
    if (f < s) return -1;
    return 0;
}

#define REPEATS (200)

uint64_t ns[REPEATS];
uint64_t ns_sorted[REPEATS];

const char * header_text[]  = { "last_p0/2", "p0/2+%", "p0", "p1=p0+%", "p25=p0+%", "p50=p0+%", "p75=p0+%", "p99=p0+%", "p100=p0+%", "p0*R+%", "=row_sec", "", };
const int    header_width[] = {         10 ,       8 ,  11 ,        9 ,         9 ,         9 ,         9 ,         9 ,          11,       7 ,         9 , 10, };

// note: never inline this function so that compiler optimization is hopefully limited to this function only, and not surrounding code if inlined
__attribute__ ((noinline)) uint64_t burn_cpu(int loops) {
    __volatile uint64_t count = 0; // note: "__volatile" stops gcc from optimizing the loop away :-)
    uint64_t t1 = get_time_in_hires_units();
    do {
        loops --;
        count ++;
    } while(loops > 0); // produces less branches than for(){} or while(){}
    uint64_t t2 = get_time_in_hires_units();
    return diff_hires_units_as_ns(t1, t2);
}

int main(void) {
    setlocale(LC_NUMERIC, "");
    int cpu_num = sched_getcpu();
    if(getenv("USE_ITERATIONS")) {
        iterations = atoi(getenv("USE_ITERATIONS"));
        iterations = iterations > 0 ? iterations : 3;
    }
    printf("%.6f %s // start %d=cpu_num %lu=iterations %s=getenv(\"USE_ITERATIONS\")\n", get_time_in_s(), use_what, cpu_num, iterations, getenv("USE_ITERATIONS"));
    NEXT_RUN:;
    ini_time();
    printf("%.6f %s  %4u=REPEATS ns:", get_time_in_s(), use_what, REPEATS);
    uint64_t h = 0;
    while(header_text[h][0] != 0) {
        printf(" %*s", header_width[h], header_text[h]);
        h ++;
    }
    printf("\n");
    int bits_max = 24;
    int64_t p000_div_2_estimate = -1;
    for(int bits = bits_max; bits >= 0; bits --) {
        //uint64_t z = 0; // note: "__volatile" stops gcc from optimizing the loop away :-)
        int loops = (1 << bits);
        printf("%.6f %s %'11d=loops", get_time_in_s(), use_what, loops);
        double s0 = get_time_in_s();
        for(int r = 0; r < REPEATS; r ++) {
            //assert(r < REPEATS);
            ns[r] = burn_cpu(loops);
            ns_sorted[r] = ns[r];
        }
        double s1 = get_time_in_s();
        qsort(ns_sorted, sizeof(ns_sorted)/sizeof(*ns_sorted), sizeof(*ns_sorted), comp);
        int64_t p000 = ns_sorted[(uint64_t) (0.0  * (REPEATS - 1))];
        int64_t p001 = ns_sorted[(uint64_t) (0.01 * (REPEATS - 1))]; assert(p001 >= p000);
        int64_t p025 = ns_sorted[(uint64_t) (0.25 * (REPEATS - 1))]; assert(p025 >= p001);
        int64_t p050 = ns_sorted[(uint64_t) (0.5  * (REPEATS - 1))]; assert(p050 >= p025);
        int64_t p075 = ns_sorted[(uint64_t) (0.75 * (REPEATS - 1))]; assert(p075 >= p050);
        int64_t p099 = ns_sorted[(uint64_t) (0.99 * (REPEATS - 1))]; assert(p099 >= p075 /* p095 */);
        int64_t p100 = ns_sorted[(uint64_t) (1.0  * (REPEATS - 1))]; assert(p100 >= p099);
        p000_div_2_estimate = (-1 == p000_div_2_estimate) ? p000 : p000_div_2_estimate / 2;
        double diff_to_expected = (p000 - p000_div_2_estimate) * 100.0 / p000_div_2_estimate;

        if(bits == bits_max) { printf( " %10s" , "n/a"); }
        else                 { printf( " %'10lu", p000_div_2_estimate); }
        if((p000 > 0) && (p000_div_2_estimate > 0)) { printf( " %+'8.1f", diff_to_expected); }
        else                                        { printf( " %8s"    , "n/a"); }
        printf( " %'11lu", p000);

        double  p001_diff = (0 == p000) ? 0 : (p001 - p000) * 100.0 / p000;
        double  p025_diff = (0 == p000) ? 0 : (p025 - p000) * 100.0 / p000;
        double  p050_diff = (0 == p000) ? 0 : (p050 - p000) * 100.0 / p000;
        double  p075_diff = (0 == p000) ? 0 : (p075 - p000) * 100.0 / p000;
        double  p099_diff = (0 == p000) ? 0 : (p099 - p000) * 100.0 / p000;
        double  p100_diff = (0 == p000) ? 0 : (p100 - p000) * 100.0 / p000;

        printf(" %'+9.1f" , p001_diff);
        printf(" %'+9.1f" , p025_diff);
        printf(" %'+9.1f" , p050_diff);
        printf(" %'+9.1f" , p075_diff);
        printf(" %'+9.1f" , p099_diff);
        printf(" %'+11.1f", p100_diff);

        fprintf(stderr, "%.6f %s %'11d=loops", get_time_in_s(), use_what, loops);
        
        fprintf(stderr, " %'10lu", p000_div_2_estimate);
        if((p000 > 0) && (p000_div_2_estimate > 0)) { fprintf(stderr, " %+'10.3f", diff_to_expected); }
        else                                        { fprintf(stderr, " %10s", "n/a"); }
        fprintf(stderr, " %'10lu", p000     );

        for(int r = 0; r < REPEATS; r ++) {
            if     (ns[r] >= 10000000) { fprintf(stderr, " %3luM", ns[r] / 1000000  ); }
            else if(ns[r] >=  9900000) { fprintf(stderr, " %.1fM",               9.9); } // stop fprintf from round up to 10.0 when we want the max to be 9.9
            else if(ns[r] >=  1000000) { fprintf(stderr, " %.1fM", ns[r] / 1000000.0); }
            else if(ns[r] >=    10000) { fprintf(stderr, " %3luK", ns[r] /    1000  ); }
            else if(ns[r] >=     9900) { fprintf(stderr, " %.1fK",               9.9); } // stop fprintf from round up to 10.0 when we want the max to be 9.9
            else if(ns[r] >=     1000) { fprintf(stderr, " %.1fK", ns[r] /    1000.0); }
            else                       { fprintf(stderr, " %3lu ", ns[r]            ); }
        }
        fprintf(stderr, "\n");

        double row_elapsed_forreal = s1 - s0;
        double row_elapsed_fastest = (p000 * REPEATS) / 1000000000.0;
        double row_elapsed_pc_diff = (row_elapsed_forreal - row_elapsed_fastest) * 100.0 / row_elapsed_fastest;
        if(0 == p000) { printf("%8s", "n/a"); }
        else          { printf(" %+7.1f", row_elapsed_pc_diff); }
        printf(" %9.6f", row_elapsed_forreal);
        printf("\r\n");
    }
    iterations --;
    iteration ++;
    if(iterations > 0) {
        goto NEXT_RUN;
    }
    printf("%.6f %s // exit\n", get_time_in_s(), use_what);
}
